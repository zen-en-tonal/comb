defmodule Comb.Caching.SingleFlight do
  @moduledoc false

  use GenServer

  alias Comb.Registry

  def start_link(%{name: name} = opts),
    do: GenServer.start_link(__MODULE__, opts, name: Registry.via(name, __MODULE__))

  @impl true
  def init(%{name: name} = state) do
    case :pg.start_link(scope_for(name)) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
      other -> raise "Failed to start pg: #{inspect(other)}"
    end

    {:ok, state}
  end

  @spec run(name :: atom(), {module(), fun_name :: atom(), args :: [term()]}) ::
          term() | {:error, term()}
  def run(name, {module, fun_name, args}, timeout \\ 5_000)
      when is_atom(module) and is_atom(fun_name) do
    group = group_for({module, fun_name}, args)
    closure = fn -> apply(module, fun_name, args) end

    do_run(name, group, closure, timeout)
  end

  defp do_run(name, group, closure, timeout) do
    Registry.via(name, __MODULE__)
    |> GenServer.cast({:flight, group, closure, self()})

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

  @impl true
  def handle_cast({:flight, group, closure, caller}, %{name: name} = state) do
    scope = scope_for(name)
    :ok = :pg.join(scope, group, caller)

    leader =
      :pg.get_members(scope, group)
      |> Enum.min(fn -> nil end)

    if leader == caller do
      Module.concat(name, TaskSup)
      |> Task.Supervisor.start_child(fn ->
        res = safe(closure)
        publish(scope, group, {:done, group, res})
      end)
    end

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
