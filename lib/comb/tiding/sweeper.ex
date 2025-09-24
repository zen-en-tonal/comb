defmodule Comb.Tiding.Sweeper do
  @moduledoc false

  use GenServer

  alias Comb.{Caching, Registry}
  alias Comb.Tiding.{ExpiryWheel}

  def start_link(%{name: name} = opts),
    do: GenServer.start_link(__MODULE__, opts, name: Registry.via(name, __MODULE__))

  @impl true
  def init(state) do
    state =
      state
      |> Map.put_new(:sweep_interval_ms, 5_000)
      |> Map.put_new(:soft_limit_bytes, :infinity)
      |> Map.put_new(:hard_limit_bytes, :infinity)

    schedule_tick(state)

    {:ok, state}
  end

  defp schedule_tick(state),
    do: Process.send_after(self(), :tick, state.sweep_interval_ms)

  @impl true
  def handle_info(:tick, %{name: name} = state) do
    ids = for id <- ExpiryWheel.rotate_and_take(name), Caching.expired?(name, id), do: id

    # _ = maybe_pressure_trim(state)

    Caching.delete(name, ids)
    :telemetry.execute([:clone_cache, :sweep], %{count: length(ids)}, %{})

    schedule_tick(state)
    {:noreply, state}
  end

  # defp maybe_pressure_trim(state) do
  #   words = :ets.info(tab, :memory) || 0
  #   bytes = words * :erlang.system_info(:wordsize)

  #   cond do
  #     state.hard_limit_bytes != :infinity and bytes >= state.hard_limit_bytes ->
  #       pressure_evict(:hard, state)

  #     state.soft_limit_bytes != :infinity and bytes >= state.soft_limit_bytes ->
  #       pressure_evict(:soft, state)

  #     true ->
  #       :ok
  #   end
  # end

  # defp pressure_evict(_level, tab, state) do
  #   ids = ExpiryWheel.rotate_and_take(state.name)
  #   now = System.system_time(:millisecond)

  #   victims =
  #     for id <- ids,
  #         [{^id, v, kind, exp_ms}] <- [:ets.lookup(tab, id)],
  #         exp_ms != :infinity and exp_ms <= now + 60_000 do
  #       {id, v, kind}
  #     end

  #   case victims do
  #     [] ->
  #       :ok

  #     items ->
  #       _ = safe_offload(items, state)
  #       Enum.each(items, fn {id, _, _} -> :ets.delete(tab, id) end)
  #       :telemetry.execute([:clone_cache, :pressure_evict], %{count: length(items)}, %{})
  #   end
  # end
end
