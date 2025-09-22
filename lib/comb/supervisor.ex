defmodule Comb.Supervisor do
  @moduledoc """
  Comb の1インスタンスを管理する Supervisor。
  1テーブル = 1インスタンス。

  ## 使い方

      children = [
        {Comb.Supervisor, name: :users_cache, table_name: :users_ets,
          change_store_mod: MyApp.UserStore,
          notifier_mod: MyApp.UserNotifier,
          offload_store_mod: MyApp.Offload}
      ]

  複数のテーブルを扱う場合は、同様に別名で複数 children を追加すればOK。
  """
  use Supervisor

  def start_link(opts \\ []) do
    name = Keyword.fetch!(opts, :name)
    Supervisor.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(opts) do
    sup_name = Keyword.fetch!(opts, :name)

    table_opts =
      Keyword.get(opts, :table_opts, [:ordered_set, :named_table, {:read_concurrency, true}])

    change_store = Keyword.fetch!(opts, :change_store_mod)
    notifier = Keyword.fetch!(opts, :notifier_mod)
    offload = Keyword.fetch!(opts, :offload_store_mod)

    children = [
      {Registry, keys: :unique, name: :"#{sup_name}_registry"},
      {Comb.Table, %{name: sup_name, table_opts: table_opts}},
      {Comb.Offsets, %{name: sup_name}},
      {Comb.SingleFlight, %{name: sup_name}},
      {Comb.ExpiryWheel, %{name: sup_name}},
      {Comb.Sweeper, %{name: sup_name, offload_mod: offload}},
      {Comb.Applier,
       %{
         name: sup_name,
         change_store_mod: change_store,
         notifier_mod: notifier
       }},
      {Comb.Gap, %{name: sup_name, change_store_mod: change_store}}
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

  def via(name, module) do
    {:via, Registry, {:"#{name}_registry", module}}
  end
end
