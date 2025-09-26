defmodule Comb.Tidying do
  @moduledoc false

  defdelegate register(name, expiry_ms, id), to: Comb.Tidying.ExpiryWheel
end
