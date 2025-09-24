defmodule Comb.Tiding do
  @moduledoc false

  defdelegate register(name, expiry_ms, id), to: Comb.Tiding.ExpiryWheel
end
