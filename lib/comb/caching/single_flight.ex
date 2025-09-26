defmodule Comb.Caching.SingleFlight do
  @moduledoc false

  use GenServer

  alias Comb.Registry

  def start_link(%{name: name} = opts),
    do: GenServer.start_link(__MODULE__, opts, name: Registry.via(name, __MODULE__))

  def init(%{name: name} = state) do
    {:ok, _pid} = :pg.start_link(scope_for(name))

    {:ok, state}
  end

  @spec run(name :: atom(), fun :: function() | {module(), fun_name :: atom()}, args :: [term()]) ::
          {:ok, term()} | {:error, term()}
  def run(name, fun, args, timeout \\ 5_000)

  def run(name, fun, args, timeout) when is_function(fun) do
    group = group_for(fun, args)
    closure = fn -> apply(fun, args) end

    do_run(name, group, closure, timeout)
  end

  def run(name, {module, fun_name}, args, timeout)
      when is_atom(module) and is_atom(fun_name) do
    group = group_for({module, fun_name}, args)
    closure = fn -> apply(module, fun_name, args) end

    do_run(name, group, closure, timeout)
  end

  defp do_run(name, group, closure, timeout) do
    Registry.via(name, __MODULE__)
    |> GenServer.call({:run, group, closure, self()}, timeout)

    receive do
      {:done, ^group, result} ->
        :pg.leave(scope_for(name), group, self())
        result
    after
      timeout ->
        :pg.leave(scope_for(name), group, self())
        {:error, :timeout}
    end
  end

  def handle_call({:run, group, closure, caller}, _from, %{name: name} = state) do
    :ok = :pg.join(scope_for(name), group, caller)

    case :pg.get_members(scope_for(name), group) do
      [^caller] ->
        parent = self()

        _pid =
          spawn(fn ->
            res = safe(closure)
            GenServer.cast(parent, {:complete, group, res})
          end)

        {:reply, :ok, state}

      _already_in_flight ->
        {:reply, :ok, state}
    end
  end

  def handle_cast({:complete, group, res}, state) do
    publish(scope_for(state.name), group, {:done, group, res})

    {:noreply, state}
  end

  defp group_for(fun, arg), do: {fun, arg}

  defp scope_for(name), do: Module.concat(name, "PG")

  defp publish(scope, group, msg) do
    for pid <- :pg.get_members(scope, group), do: send(pid, msg)
  end

  defp safe(closure) do
    try do
      closure.()
    catch
      kind, reason -> {:error, {kind, reason}}
    end
  end
end
