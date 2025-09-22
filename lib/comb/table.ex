defmodule Comb.Table do
  use GenServer

  alias Comb.{Registry}

  def start_link(%{name: name} = opts) do
    GenServer.start_link(__MODULE__, opts, name: Registry.via(name, __MODULE__))
  end

  def init(%{name: tname, table_opts: topts} = state) do
    ^tname = :ets.new(tname, topts)
    {:ok, state}
  end

  def table_name(name) do
    Registry.via(name, __MODULE__)
    |> GenServer.call(:table_name)
  end

  def handle_call(:table_name, _from, %{name: tname} = st), do: {:reply, tname, st}
end
