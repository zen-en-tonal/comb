defmodule Comb.TTL do
  @moduledoc "TTL 付きの ETS 挿入/延長ヘルパ"
  alias Comb.{Table, ExpiryWheel}

  @spec insert_with_ttl(
          name :: atom(),
          {term(), non_neg_integer(), {:val, term()} | :tomb},
          :infinity | non_neg_integer()
        ) :: :ok
  def insert_with_ttl(name, {id, v, kind}, ttl_ms) do
    exp =
      case ttl_ms do
        :infinity -> :infinity
        ms when is_integer(ms) -> System.system_time(:millisecond) + ms
      end

    :ets.insert(Table.table_name(name), {id, v, kind, exp})
    if exp != :infinity, do: ExpiryWheel.register(name, exp, id)
    :ok
  end

  def touch(name, id, ttl_ms) do
    tab = Table.table_name(name)

    case :ets.lookup(tab, id) do
      [{^id, v, kind, _}] -> insert_with_ttl(name, {id, v, kind}, ttl_ms)
      _ -> :ok
    end
  end
end
