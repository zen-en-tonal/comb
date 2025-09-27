## 擬似DB：Agent に {id => {version, value}} を保持し、Comb.fetch_one が参照
defmodule Comb.FakeDB do
  def start_link, do: Agent.start_link(fn -> %{} end)
  def put(db, id, v, val), do: Agent.update(db, &Map.put(&1, id, {v, val}))
  def del(db, id), do: Agent.update(db, &Map.delete(&1, id))
  def get(db, id), do: Agent.get(db, &Map.get(&1, id))
end

defmodule Comb.StateM do
  use PropCheck.StateM

  alias Comb.FakeDB
  alias PropCheck.BasicTypes, as: T

  @impl true
  def initial_state() do
    {:ok, db} = FakeDB.start_link()

    name = unique_name()

    fetch_one = fn id ->
      case FakeDB.get(db, id) do
        nil -> {:ok, nil}
        {v, val} -> {:ok, {v, val}}
      end
    end

    {:ok, _pid} =
      Comb.start_link(
        name: name,
        fetch_one: fetch_one,
        ttl_pos: 60_000,
        ttl_neg: 60_000,
        sweep_interval_ms: 60_000
      )

    %{name: name, db_pid: db, db: %{}}
  end

  @impl true
  def command(state) do
    frequency([
      {1, {:call, Comb, :fetch, [state.name, ids()]}},
      {1, {:call, Comb, :notify_changed, [state.name, {ids(), pos_integer(), term()}]}}
    ])
  end

  defp ids, do: T.choose(1, 10)

  @impl true
  def precondition(_state, {:call, Comb, :fetch, [_name, _id]}), do: true
  def precondition(_state, {:call, Comb, :notify_changed, [_name, _entry]}), do: true

  @impl true
  def postcondition(state, {:call, Comb, :fetch, [_name, id]}, res) do
    {state.db[id], res}
    |> case do
      {nil, {:error, :not_found}} -> true
      {{_v, s_value}, {:ok, c_value}} -> s_value == c_value
      _ -> false
    end
  end

  def postcondition(state, {:call, Comb, :notify_changed, [name, {id, version, value}]}, _res) do
    # wait a bit for Comb to process notify_changed
    :timer.sleep(5)

    {state.db[id], Comb.fetch(name, id)}
    |> case do
      # new value should be ok
      {nil, {:ok, ^value}} -> true
      # new version should be ok
      {{v, _}, {:ok, ^value}} when v < version -> true
      # notified value with old version should be no affect
      {{v, state_value}, {:ok, cache_value}} when v >= version -> state_value == cache_value
      _ -> false
    end
  end

  @impl true
  def next_state(state, _res, {:call, Comb, :fetch, [_name, _id]}), do: state
  def next_state(state, _res, {:call, Comb, :notify_changed, [_name, {id, version, value}]}) do
    case state.db[id] do
      nil -> Map.update!(state, :db, fn db -> Map.put(db, id, {version, value}) end)
      {ver, _} when ver < version -> Map.update!(state, :db, fn db -> %{db | id => {version, value}} end)
      _ -> state
    end
  end

  ## ---- helpers ----
  defp unique_name, do:
    String.to_atom("comb_" <> Base.encode16(:crypto.strong_rand_bytes(6)))
end

defmodule Comb.PropertyTest do
  use ExUnit.Case, async: true
  use PropCheck

  doctest Comb

  alias PropCheck.StateM

  property "Comb behaves like the model", numtests: 500 do
    forall cmds in StateM.commands(Comb.StateM) do
      {history, _state, result} = StateM.run_commands(Comb.StateM, cmds)

      (result == :ok)
      |> when_fail(IO.puts("Counterexample (shrunk) history:\n#{inspect(history, pretty: true)}"))
      |> aggregate(StateM.command_names(cmds))
    end
  end
end
