defmodule Comb.Api do
  @moduledoc """
  読みAPI（read-through + tombstone）。存在しないキーは墓標をネガティブキャッシュ。
  """
  alias Comb.{Table, TTL, SingleFlight, Offsets}

  @spec get(atom(), term()) :: {:ok, any(), non_neg_integer()} | :not_found
  def get(name, id) do
    tab = Table.table_name(name)
    now = System.system_time(:millisecond)

    case :ets.lookup(tab, id) do
      [{^id, v, {:val, val}, exp}] when exp == :infinity or exp > now ->
        {:ok, val, v}

      [{^id, _v, :tomb, exp}] when exp == :infinity or exp > now ->
        :not_found

      _ ->
        fetch_and_cache(name, id)
    end
  end

  def latest(name), do: Offsets.last(name)

  defp fetch_and_cache(name, id) do
    SingleFlight.run(name, {:fetch, id}, fn -> do_fetch(name, id) end)
  end

  defp do_fetch(name, id) do
    # case store.fetch_one(id) do
    #   {:ok, {v, value}} ->
    #     TTL.insert_with_ttl({id, v, {:val, value}}, @ttl_pos)
    #     {:ok, value, v}

    #   :not_found ->
    #     TTL.insert_with_ttl({id, 0, :tomb}, @ttl_neg)
    #     :not_found

    #   {:error, _} ->
    #     :not_found
    # end
  end
end
