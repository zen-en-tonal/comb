defmodule Comb do
  @moduledoc """
  Comb is a caching library with versioning and negative caching.

  ## Features
  - Caches values with a version number.
  - Supports negative caching (caching of not-found entries).
  - Automatic expiration of cached entries based on TTL (time-to-live).
  - Periodic sweeping of expired entries.
  - Notifies changes to cached entries to update or invalidate them.

  ## Usage
  to use Comb, you need to start a Comb supervisor with the required options.
  and then use the `Comb.get/2` function to get cached values.
  you can use `Comb.notify_changed/2` to notify changes.

      iex> db = %{1 => {1, "value1"}, 2 => {1, "value2"}}
      %{1 => {1, "value1"}, 2 => {1, "value2"}}
      iex> {:ok, _pid} = Comb.start_link(name: MyApp.Cache, fetch_one: fn id -> {:ok, db[id]} end)
      iex> Comb.get(MyApp.Cache, 1)
      {:ok, "value1"}
      iex> Comb.get(MyApp.Cache, 3)
      :not_found
      iex> Comb.notify_changed(MyApp.Cache, {3, 1, "value3"})
      :ok

  """

  @type id :: term()
  @type version :: non_neg_integer()
  @type value :: {:val, term()} | :tomb
  @type fetch_one :: (id() -> {:ok, {version(), term()} | nil} | {:error, term()})

  @type option ::
          {:name, atom()}
          | {:fetch_one, fetch_one()}
          | {:ttl_pos, non_neg_integer()}
          | {:ttl_neg, non_neg_integer()}
          | {:sweep_interval_ms, non_neg_integer()}
          | Supervisor.option()

  @doc """
  start the Comb supervisor.

  options:

    * `:name` - the name of this cache. required.
    * `:fetch_one` - a function to fetch one entry by id. required.
      the function is called as `fetch_one.(id)`, and should return
      `{:ok, {version :: non_neg_integer(), value :: term()} | nil}`
      or `{:error, reason :: term()}`.
      if the entry is not found, it should return `{:ok, nil}`.
    * `:ttl_pos` - the time-to-live in milliseconds for positive cache (default: 60_000)
    * `:ttl_neg` - the time-to-live in milliseconds for negative cache (default: 300_000)
    * `:sweep_interval_ms` - the interval in milliseconds to sweep expired entries (default: 60_000)
    * other options are passed to the underlying `Supervisor`.
  """
  @spec start_link([option()]) :: Supervisor.on_start()
  def start_link(opts), do: Comb.Supervisor.start_link(opts)

  @doc """
  get the cached value on `name` by `id`.
  returns `{:ok, value}` or `:not_found`.

  if the value is not cached or expired, it calls the `fetch_one` function
  given at the startup to get the value, and caches it.
  """
  @spec get(name :: atom(), id()) :: {:ok, term()} | :not_found
  def get(name, id), do: Comb.Caching.get(name, id)

  @doc """
  notify that the entry is changed.

  if `value` is `nil`, it means the entry is deleted.

  the `version` is the new version.
  if the `version` is not greater than the cached version, the cache is not updated.
  """
  @spec notify_changed(name :: atom(), entry :: {id(), version(), nil | term()}) ::
          :ok | {:error, reason :: term()}
  def notify_changed(name, entry), do: Comb.Refreshing.changed(name, entry)
end
