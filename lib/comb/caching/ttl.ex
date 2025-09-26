defmodule Comb.Caching.TTL do
  @moduledoc false

  alias Comb.Caching.Table
  alias Comb.Tidying

  @type ttl ::
          {:expire_in, ms :: non_neg_integer()}
          | {:ttl, ms :: non_neg_integer()}
          | :infinity

  @type entry :: {Table.id(), Table.version(), Table.value()}

  @spec insert(name :: atom(), entry(), ttl()) :: :ok
  def insert(name, entry, ttl \\ :infinity, now \\ System.system_time(:millisecond))

  def insert(name, {id, v, kind}, :infinity, _) do
    Table.insert(name, {id, v, kind, :infinity})
  end

  def insert(name, {id, v, kind}, {:expire_in, exp}, _) do
    Table.insert(name, {id, v, kind, exp})
    Tidying.register(name, exp, id)
    :ok
  end

  def insert(name, {id, v, kind}, {:ttl, ms}, now) do
    exp = now + ms
    insert(name, {id, v, kind}, {:expire_in, exp}, now)
  end

  @spec touch(name :: atom(), id :: term(), ttl()) :: :ok
  def touch(name, id, ttl) do
    case Table.lookup(name, id) do
      {^id, v, kind, _} ->
        insert(name, {id, v, kind}, ttl)
        :ok

      _ ->
        :ok
    end
  end
end
