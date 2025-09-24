defmodule Comb.Refreshing.Applier do
  @moduledoc false

  use GenServer

  alias Comb.{Caching, Registry}
  alias Comb.Refreshing.Notifier

  def start_link(%{name: name} = opts),
    do: GenServer.start_link(__MODULE__, opts, name: Registry.via(name, __MODULE__))

  @impl true
  def init(%{name: name} = state) do
    :ok = Notifier.subscribe(name)
    {:ok, state}
  end

  @impl true
  def handle_info({:change_notice, entry}, st) do
    apply_one(entry, st)
    {:noreply, st}
  end

  defp apply_one({id, v, nil}, %{name: name}) do
    ttl_neg = :persistent_term.get({name, :ttl_neg})
    Caching.put(name, id, {v, :tomb}, {:ttl, ttl_neg})
    :telemetry.execute([:clone_cache, :applied], %{count: 1}, %{version: v, kind: :tomb})
  end

  defp apply_one({id, v, val}, %{name: name}) do
    ttl_pos = :persistent_term.get({name, :ttl_pos})
    Caching.put(name, id, {v, {:val, val}}, {:ttl, ttl_pos})
    :telemetry.execute([:clone_cache, :applied], %{count: 1}, %{version: v, kind: :val})
  end
end
