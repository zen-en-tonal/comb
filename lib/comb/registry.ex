defmodule Comb.Registry do
  @moduledoc false

  def via(name, module), do: {:via, Registry, {reg_name(name), module}}

  def reg_name(name), do: Module.concat(name, "Registry")
end
