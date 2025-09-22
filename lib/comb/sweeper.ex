defmodule Comb.Sweeper do
  use GenServer
  alias Comb.{Table, ExpiryWheel, Registry}

  def start_link(%{name: name} = opts),
    do: GenServer.start_link(__MODULE__, opts, name: Registry.via(name, __MODULE__))

  @impl true
  def init(state) do
    state =
      state
      |> Map.put_new(:sweep_interval_ms, 5_000)
      |> Map.put_new(:soft_limit_bytes, :infinity)
      |> Map.put_new(:hard_limit_bytes, :infinity)
      |> Map.put_new(:offload_module, nil)

    schedule_tick(state)

    {:ok, state}
  end

  defp schedule_tick(state),
    do: Process.send_after(self(), :tick, state.sweep_interval_ms)

  @impl true
  def handle_info(:tick, state) do
    ids = ExpiryWheel.rotate_and_take(state.name)
    now = System.system_time(:millisecond)
    tab = Table.table_name(state.name)

    expired =
      for id <- ids,
          [{^id, v, kind, exp_ms}] <- [:ets.lookup(tab, id)],
          exp_ms != :infinity and exp_ms <= now do
        {id, v, kind}
      end

    _ = maybe_pressure_trim(tab, state)

    case expired do
      [] ->
        :ok

      items ->
        _ = safe_offload(items, state)
        Enum.each(items, fn {id, _v, _} -> :ets.delete(tab, id) end)
        :telemetry.execute([:clone_cache, :sweep], %{count: length(items)}, %{})
    end

    schedule_tick(state)
    {:noreply, state}
  end

  defp safe_offload(items, state) do
    case state.offload_module.offload_expired(items) do
      :ok -> :ok
      {:error, _} -> :ok
    end
  end

  defp maybe_pressure_trim(tab, state) do
    words = :ets.info(tab, :memory) || 0
    bytes = words * :erlang.system_info(:wordsize)

    cond do
      state.hard_limit_bytes != :infinity and bytes >= state.hard_limit_bytes ->
        pressure_evict(:hard, tab, state)

      state.soft_limit_bytes != :infinity and bytes >= state.soft_limit_bytes ->
        pressure_evict(:soft, tab, state)

      true ->
        :ok
    end
  end

  defp pressure_evict(_level, tab, state) do
    ids = ExpiryWheel.rotate_and_take(state.name)
    now = System.system_time(:millisecond)

    victims =
      for id <- ids,
          [{^id, v, kind, exp_ms}] <- [:ets.lookup(tab, id)],
          exp_ms != :infinity and exp_ms <= now + 60_000 do
        {id, v, kind}
      end

    case victims do
      [] ->
        :ok

      items ->
        _ = safe_offload(items, state)
        Enum.each(items, fn {id, _, _} -> :ets.delete(tab, id) end)
        :telemetry.execute([:clone_cache, :pressure_evict], %{count: length(items)}, %{})
    end
  end
end
