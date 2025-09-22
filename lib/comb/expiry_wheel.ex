defmodule Comb.ExpiryWheel do
  @moduledoc false
  use GenServer

  alias Comb.{Registry}

  # TODO: exp - now > wheel_slots * wheel_granularity_ms の場合に
  #       exp = now + wheel_slots * wheel_granularity_ms にフォールバック

  def start_link(%{name: name} = opts),
    do: GenServer.start_link(__MODULE__, opts, name: Registry.via(name, __MODULE__))

  @impl true
  def init(state) do
    wheel_slots = state |> Map.get(:wheel_slots, 720)
    slots = for(_ <- 1..wheel_slots, do: MapSet.new())

    state =
      state
      |> Map.put(:wheel_slots, wheel_slots)
      |> Map.put_new(:wheel_granularity_ms, 5_000)
      |> Map.put(:idx, 0)
      |> Map.put(:slots, slots)

    {:ok, state}
  end

  @doc "期限(ミリ秒UNIX)とidを登録"
  def register(name, expiry_ms, id),
    do: GenServer.cast(Registry.via(name, __MODULE__), {:register, expiry_ms, id})

  @doc "idを全スロットから外す（再登録/削除時）"
  def deregister(name, id),
    do: GenServer.cast(Registry.via(name, __MODULE__), {:deregister, id})

  @doc "現在スロットを進め、回収対象id集合を返す"
  def rotate_and_take(name),
    do: GenServer.call(Registry.via(name, __MODULE__), :rotate_and_take)

  @impl true
  def handle_cast({:register, expiry_ms, id}, state) do
    slot = slot_for(expiry_ms, state)
    {:noreply, put_in_slot(state, slot, id)}
  end

  def handle_cast({:deregister, id}, s) do
    slots = Enum.map(s.slots, &MapSet.delete(&1, id))
    {:noreply, %{s | slots: slots}}
  end

  @impl true
  def handle_call(:rotate_and_take, _from, %{idx: i, wheel_slots: n, slots: slots} = s) do
    next = rem(i + 1, n)
    ids = Enum.at(slots, next)
    slots2 = List.replace_at(slots, next, MapSet.new())
    {:reply, ids, %{s | idx: next, slots: slots2}}
  end

  defp slot_for(expiry_ms, %{wheel_granularity_ms: gran, wheel_slots: n}) do
    div(expiry_ms, gran) |> rem(n)
  end

  defp put_in_slot(%{slots: slots} = s, slot, id) do
    cur = Enum.at(slots, slot)
    slots2 = List.replace_at(slots, slot, MapSet.put(cur, id))
    %{s | slots: slots2}
  end
end
