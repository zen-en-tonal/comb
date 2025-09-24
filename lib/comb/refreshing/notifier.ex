defmodule Comb.Refreshing.Notifier do
  @moduledoc false

  @type entry :: {id :: term(), version :: non_neg_integer(), value()}
  @type value :: nil | term()

  defp topic(name), do: "change/#{name}"

  @spec changed(name :: atom(), entry()) :: :ok | {:error, reason :: term()}
  def changed(name, entry) do
    Phoenix.PubSub.broadcast(__MODULE__, topic(name), {:change_notice, entry})
  end

  def subscribe(name) do
    Phoenix.PubSub.subscribe(__MODULE__, topic(name))
  end
end
