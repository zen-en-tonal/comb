defmodule Comb.Registry do
  def via(name, module) do
    {:via, Registry, {reg_name(name), module}}
  end

  def reg_name(name) do
    :"#{name}_registry"
  end
end
