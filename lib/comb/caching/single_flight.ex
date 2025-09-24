defmodule Comb.Caching.SingleFlight do
  @moduledoc false

  use GenServer

  alias Comb.{Registry}

  def start_link(%{name: name} = opts),
    do: GenServer.start_link(__MODULE__, opts, name: Registry.via(name, __MODULE__))

  def init(state) do
    {:ok, state}
  end

  def run(name, arg, fun, timeout \\ 5_000) do
    ref = make_ref()

    Registry.via(name, __MODULE__)
    |> GenServer.call({:run, arg, ref, self(), fun}, timeout)

    receive do
      {^ref, result} -> result
    end
  end

  def handle_call({:run, arg, ref, caller, fun}, _from, state) do
    case Map.get(state, {fun, arg}) do
      nil ->
        parent = self()

        pid =
          spawn_link(fn ->
            res = safe(fun, arg)
            GenServer.cast(parent, {:complete, fun, arg, res})
          end)

        {:reply, :ok, Map.put(state, {fun, arg}, %{waiters: [{ref, caller}], pid: pid})}

      %{waiters: waiters} = entry ->
        {:reply, :ok, Map.put(state, {fun, arg}, %{entry | waiters: [{ref, caller} | waiters]})}
    end
  end

  def handle_cast({:complete, fun, arg, res}, state) do
    case Map.pop(state, {fun, arg}) do
      {nil, st} ->
        {:noreply, st}

      {%{waiters: waiters}, st} ->
        Enum.each(waiters, fn {ref, pid} -> send(pid, {ref, res}) end)
        {:noreply, st}
    end
  end

  defp safe(fun, arg) do
    try do
      fun.(arg)
    catch
      c, r -> {:error, {c, r}}
    end
  end
end
