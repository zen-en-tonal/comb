defmodule Comb.Caching.Table do
  use GenServer

  @moduledoc false

  alias Comb.{Registry}

  @type id :: term()
  @type version :: non_neg_integer()
  @type entry ::
          {id(), version(), value(), exp_ms :: non_neg_integer() | :infinity}
  @type value :: {:val, term()} | :tomb

  def start_link(%{name: name} = opts) do
    GenServer.start_link(__MODULE__, opts, name: Registry.via(name, __MODULE__))
  end

  def init(%{name: tname} = state) do
    ^tname = :ets.new(tname, [:ordered_set, :named_table, {:read_concurrency, true}])
    {:ok, state}
  end

  @spec lookup(name :: atom(), id()) :: entry() | nil
  def lookup(name, id) do
    Registry.via(name, __MODULE__)
    |> GenServer.call({:lookup, id})
  end

  @spec insert(name :: atom(), entry(), :no_degrade | :force) :: :ok
  def insert(name, entry, mode \\ :no_degrade) do
    Registry.via(name, __MODULE__)
    |> GenServer.call({:insert, entry, mode})
  end

  @spec delete(name :: atom(), id() | [id()]) :: :ok
  def delete(name, id) do
    Registry.via(name, __MODULE__)
    |> GenServer.call({:delete, id})
  end

  def handle_call({:lookup, id}, _from, %{name: tname} = s) do
    {:reply, :ets.lookup(tname, id) |> List.first(), s}
  end

  def handle_call({:insert, {id, v, _val, _ext} = ent, :no_degrade}, _from, %{name: tname} = s) do
    case :ets.lookup(tname, id) do
      [{^id, cur_v, _, _}] when cur_v < v ->
        :ets.insert(tname, ent)

      [] ->
        :ets.insert(tname, ent)

      _ ->
        :ok
    end

    {:reply, :ok, s}
  end

  def handle_call({:insert, entry, :force}, _from, %{name: tname} = s) do
    :ets.insert(tname, entry)
    {:reply, :ok, s}
  end

  def handle_call({:delete, ids}, _from, %{name: tname} = s) when is_list(ids) do
    Enum.each(ids, fn id -> :ets.delete(tname, id) end)
    {:reply, :ok, s}
  end

  def handle_call({:delete, id}, _from, %{name: tname} = s) do
    :ets.delete(tname, id)
    {:reply, :ok, s}
  end
end
