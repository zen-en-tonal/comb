defmodule Comb.Refreshing do
  @moduledoc false

  alias Comb.Refreshing.Notifier

  @type value :: nil | term()
  @type entry :: {id :: term(), version :: non_neg_integer(), value()}

  @spec changed(name :: atom(), entry()) :: :ok | {:error, reason :: term()}
  def changed(name, entry), do: Notifier.changed(name, entry)
end
