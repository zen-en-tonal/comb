defmodule Comb.Offsets do
  use GenServer

  alias Comb.{Registry}

  def start_link(%{name: name} = opts) do
    GenServer.start_link(__MODULE__, opts, name: Registry.via(name, __MODULE__))
  end

  @impl true
  def init(opts) do
    state =
      opts
      |> Map.put_new(:dets_file, opts.name)

    {:ok, state, {:continue, nil}}
  end

  @impl true
  def handle_continue(_, state) do
    {:ok, tab} = :dets.open_file(state.name, [{:file, state.dets_file}, {:type, :set}])

    v =
      case :dets.lookup(tab, :last_applied) do
        [] -> 0
        [{:last_applied, x}] -> x
      end

    state =
      state
      |> Map.put(:tab, tab)
      |> Map.put(:v, v)

    {:noreply, state}
  end

  @impl true
  def terminate(_reason, %{tab: tab}),
    do: :ok = :dets.close(tab)

  def store(name, v),
    do: GenServer.cast(Registry.via(name, __MODULE__), {:store, v})

  def last(name),
    do: GenServer.call(Registry.via(name, __MODULE__), :get)

  @impl true
  def handle_cast({:store, v}, %{tab: tab} = s) do
    :ok = :dets.insert(tab, {:last_applied, v})
    {:noreply, %{s | v: v}}
  end

  @impl true
  def handle_call(:get, _from, %{v: v} = s), do: {:reply, v, s}
end
