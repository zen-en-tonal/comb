defmodule Comb.Gap do
  @moduledoc false
  use GenServer

  alias Comb.{Applier, Registry}

  def start_link(%{name: name} = opts),
    do: GenServer.start_link(__MODULE__, opts, name: Registry.via(name, __MODULE__))

  @impl true
  def init(opts) do
    state =
      opts
      |> Map.put_new(:batch_limit, 2_000)

    {:ok, state}
  end

  @spec fill(name :: atom, from :: non_neg_integer(), to :: non_neg_integer()) ::
          :ok | {:error, term()}
  def fill(name, from, to) when from <= to,
    do: GenServer.call(Registry.via(name, __MODULE__), {:fill, from, to}, :infinity)

  def fill(_, _, _), do: :ok

  @impl true
  def handle_call({:fill, from, to}, _from, state) do
    t0 = System.monotonic_time()
    res = loop_fill(from, to, state)
    dt = System.monotonic_time() - t0

    :telemetry.execute([:clone_cache, :gap, :filled], %{duration_native: dt}, %{
      from: from,
      to: to
    })

    {:reply, res, state}
  end

  defp loop_fill(from, to, %{change_store_mod: store_mod, batch_limit: limit, name: name})
       when from <= to do
    case store_mod.fetch_changes(from, to, limit) do
      {:ok, batch, next_from} ->
        # batch :: [{v,id,kind}] => applier wants [{id,v,kind}]
        Applier.apply_batch(name, Enum.map(batch, fn {v, id, kind} -> {id, v, kind} end))
        loop_fill(next_from, to)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp loop_fill(from, to) when from > to, do: :ok
end
