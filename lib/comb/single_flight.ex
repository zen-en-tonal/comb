defmodule Comb.SingleFlight do
  @moduledoc """
  同一キーの同時 fetch を単一化。API: run(key, fun, timeout?)
  """
  use GenServer

  alias Comb.{Registry}

  def start_link(%{name: name} = opts),
    do: GenServer.start_link(__MODULE__, opts, name: Registry.via(name, __MODULE__))

  def run(name, key, fun, timeout \\ 5_000) do
    ref = make_ref()
    GenServer.call(Registry.via(name, __MODULE__), {:run, key, ref, self(), fun}, timeout)

    receive do
      {^ref, result} -> result
    end
  end

  def init(state), do: {:ok, state}

  def handle_call({:run, key, ref, caller, fun}, _from, state) do
    case Map.get(state, key) do
      nil ->
        parent = self()

        pid =
          spawn_link(fn ->
            res = safe(fun)
            GenServer.cast(parent, {:complete, key, res})
          end)

        {:reply, :ok, Map.put(state, key, %{waiters: [{ref, caller}], pid: pid})}

      %{waiters: waiters} = entry ->
        {:reply, :ok, Map.put(state, key, %{entry | waiters: [{ref, caller} | waiters]})}
    end
  end

  def handle_cast({:complete, key, res}, state) do
    case Map.pop(state, key) do
      {nil, st} ->
        {:noreply, st}

      {%{waiters: waiters}, st} ->
        Enum.each(waiters, fn {ref, pid} -> send(pid, {ref, res}) end)
        {:noreply, st}
    end
  end

  defp safe(fun) do
    try do
      fun.()
    catch
      c, r -> {:error, {c, r}}
    end
  end
end
