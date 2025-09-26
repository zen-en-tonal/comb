defmodule Comb.Tidying.ExpiryWheel do
  @moduledoc false

  use GenServer

  alias Comb.{Registry}

  import Comb.Caching, only: [is_expired: 2]

  def start_link(%{name: name} = opts),
    do: GenServer.start_link(__MODULE__, opts, name: Registry.via(name, __MODULE__))

  @impl true
  def init(state) do
    wheel_slots = state |> Map.get(:wheel_slots, 720)
    grans = state |> Map.get(:wheel_granularity_ms, 5_000)
    slots = for(_ <- 1..wheel_slots, do: %{})
    idx = slot_for(System.system_time(:millisecond), grans, wheel_slots)

    state =
      state
      |> Map.put(:wheel_slots, wheel_slots)
      |> Map.put(:wheel_granularity_ms, grans)
      |> Map.put(:max_ttl_ms, grans * wheel_slots)
      |> Map.put(:idx, idx)
      |> Map.put(:slots, slots)

    {:ok, state}
  end

  @doc "期限(ミリ秒UNIX)とidを登録"
  def register(name, expiry_ms, id) do
    name = Registry.via(name, __MODULE__)
    GenServer.cast(name, {:deregister, id})
    GenServer.cast(name, {:register, expiry_ms, id})
  end

  @doc "idを全スロットから外す（再登録/削除時）"
  def deregister(name, id),
    do: GenServer.cast(Registry.via(name, __MODULE__), {:deregister, id})

  @doc "現在スロットを進め、回収対象id集合を返す"
  def rotate_and_take(name),
    do:
      GenServer.call(
        Registry.via(name, __MODULE__),
        {:rotate_and_take, System.system_time(:millisecond)}
      )

  @impl true
  def handle_cast({:register, expiry_ms, id}, state) do
    slot = slot_for(expiry_ms, state.wheel_granularity_ms, state.wheel_slots)
    {:noreply, put_in_slot(state, slot, id, expiry_ms)}
  end

  @impl true
  def handle_cast({:deregister, id}, s) do
    slots = Enum.map(s.slots, &Map.delete(&1, id))
    {:noreply, %{s | slots: slots}}
  end

  @impl true
  def handle_call({:rotate_and_take, now}, _from, %{idx: i, wheel_slots: n, slots: slots} = s) do
    next = rem(i + 1, n)

    {expired, lives} =
      slots
      |> Enum.at(next)
      |> Enum.split_with(fn
        {_id, exp} when is_expired(exp, now) -> true
        _ -> false
      end)

    slots = slots |> List.replace_at(next, lives |> Enum.into(%{}))
    {:reply, expired |> Enum.map(&elem(&1, 0)), %{s | idx: next, slots: slots}}
  end

  defp slot_for(ms, gran, n) do
    div(ms, gran) |> rem(n)
  end

  defp put_in_slot(%{slots: slots} = s, idx, id, expiry_ms) do
    %{s | slots: List.update_at(slots, idx, &Map.put(&1, id, expiry_ms))}
  end
end
