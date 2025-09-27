defmodule Comb.Supervisor do
  @moduledoc false

  use Supervisor

  def start_link(opts \\ []) do
    name =
      opts[:name] ||
        raise ArgumentError, "the :name option is required when starting Comb"

    sup_name = Module.concat(name, "Supervisor")

    Supervisor.start_link(__MODULE__, opts, name: sup_name)
  end

  @impl true
  def init(opts) do
    sup_name = Keyword.fetch!(opts, :name)

    :persistent_term.put({sup_name, :fetch_one}, Keyword.fetch!(opts, :fetch_one))
    :persistent_term.put({sup_name, :ttl_pos}, Keyword.get(opts, :ttl_pos_ms, 60_000))
    :persistent_term.put({sup_name, :ttl_neg}, Keyword.get(opts, :ttl_neg_ms, 300_000))

    children = [
      {Registry, keys: :unique, name: Comb.Registry.reg_name(sup_name)},
      {Comb.Caching.Table, %{name: sup_name}},
      {Task.Supervisor, name: Module.concat(sup_name, TaskSup)},
      {Comb.Caching.SingleFlight, %{name: sup_name}},
      {Comb.Tidying.ExpiryWheel, %{name: sup_name}},
      {Comb.Tidying.Sweeper, %{name: sup_name}},
      {Comb.Refreshing.Applier, %{name: sup_name}}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor,
      restart: :permanent,
      shutdown: 5000
    }
  end
end
