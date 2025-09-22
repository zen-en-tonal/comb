defmodule Comb.Applier do
  @moduledoc false
  use GenServer

  alias Comb.{Table, Offsets, TTL, Gap, Registry}

  def start_link(%{name: name} = opts),
    do: GenServer.start_link(__MODULE__, opts, name: Registry.via(name, __MODULE__))

  @impl true
  def init(%{name: name, notifier_mod: notifier} = opts) do
    state =
      opts
      |> Map.put(:hi, Offsets.last(name))
      |> Map.put(:table, Table.table_name(name))

    # {:ok, _pid} = notifier.start_link(self())
    {:ok, state}
  end

  @impl true
  def handle_info({:change_notice, v}, %{name: name, hi: hi} = st) do
    if v > hi + 1, do: Gap.fill(name, hi + 1, v)
    {:noreply, st}
  end

  @spec apply_batch(name :: atom(), [
          {id :: term(), v :: non_neg_integer(), kind :: {:val, term()} | :tomb}
        ]) ::
          :ok
  def apply_batch(name, list),
    do:
      Registry.via(name, __MODULE__)
      |> GenServer.cast({:apply_batch, list})

  @impl true
  def handle_cast({:apply_batch, list}, st) do
    list
    |> Enum.sort_by(fn {_, v, _} -> v end)
    |> Enum.each(&apply_one(st.table, &1))

    hi = list |> Enum.map(fn {_, v, _} -> v end) |> Enum.max(fn -> st.hi end)
    {:noreply, %{st | hi: hi}}
  end

  defp apply_one(table, {id, v, {:val, val}}) do
    case :ets.lookup(table, id) do
      [{^id, cur_v, _kind, _exp}] when v <= cur_v ->
        :ok

      _ ->
        TTL.insert_with_ttl({id, v, {:val, val}}, @ttl_pos)
        Offsets.store(v)
        :telemetry.execute([:clone_cache, :applied], %{count: 1}, %{version: v, kind: :val})
    end
  end

  defp apply_one(table, {id, v, :tomb}) do
    case :ets.lookup(table, id) do
      [{^id, cur_v, _kind, _exp}] when v <= cur_v ->
        :ok

      _ ->
        TTL.insert_with_ttl({id, v, :tomb}, @ttl_neg)
        Offsets.store(v)
        :telemetry.execute([:clone_cache, :applied], %{count: 1}, %{version: v, kind: :tomb})
    end
  end
end
