defmodule Comb.Caching do
  @moduledoc false

  alias Comb.Caching.{Table, TTL, SingleFlight}

  @type id :: term()
  @type version :: non_neg_integer()
  @type value :: {:val, term()} | :tomb
  @type ttl :: TTL.ttl()
  @type fetch_one :: {module(), fun_name :: atom()} | function()

  defguard is_expired(exp, now)
           when exp != :infinity and now > exp

  @spec put(name :: atom(), id(), {version(), value()}, ttl()) :: :ok
  def put(name, id, {version, value}, ttl_ms \\ :infinity) do
    TTL.insert(name, {id, version, value}, ttl_ms)
  end

  @spec lookup(name :: atom(), id :: id()) ::
          {id(), version(), value(), exp_in_ms :: non_neg_integer()} | nil
  def lookup(name, id), do: Table.lookup(name, id)

  @spec delete(name :: atom(), id :: id() | [id()]) :: :ok
  def delete(name, id), do: Table.delete(name, id)

  @spec get(name :: atom(), id()) :: {:ok, term()} | :not_found
  def get(name, id, now \\ System.system_time(:millisecond)) do
    case lookup(name, id) do
      {_, _v, {:val, val}, exp} when not is_expired(exp, now) ->
        {:ok, val}

      {_, _v, :tomb, exp} when not is_expired(exp, now) ->
        :not_found

      _ ->
        fetch_and_cache(name, id)
    end
  end

  defp fetch_and_cache(name, id) do
    SingleFlight.run(name, {__MODULE__, :do_fetch}, [name, id])
  end

  @doc false
  def do_fetch(name, id) do
    ttl_pos = :persistent_term.get({name, :ttl_pos})
    ttl_neg = :persistent_term.get({name, :ttl_neg})

    :persistent_term.get({name, :fetch_one})
    |> case do
      {mod, fun} -> apply(mod, fun, [id])
      closure -> apply(closure, [id])
    end
    |> case do
      {:ok, {v, value}} ->
        put(name, id, {v, {:val, value}}, {:ttl, ttl_pos})
        {:ok, value}

      {:ok, nil} ->
        put(name, id, {0, :tomb}, {:ttl, ttl_neg})
        :not_found

      {:error, _} ->
        :not_found
    end
  end

  @spec exists?(name :: atom(), id()) :: boolean()
  def exists?(name, id, now \\ System.system_time(:millisecond)) do
    case lookup(name, id) do
      {_, _v, {:val, _val}, exp} when not is_expired(exp, now) -> true
      _ -> false
    end
  end

  @spec expired?(name :: atom(), id()) :: boolean()
  def expired?(name, id, now \\ System.system_time(:millisecond)) do
    case lookup(name, id) do
      {_, _v, _, exp} when is_expired(exp, now) -> true
      _ -> false
    end
  end
end
