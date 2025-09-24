defmodule Comb.Application do
  @moduledoc false
  use Application

  def start(_, _) do
    children = [
      {Phoenix.PubSub, name: Comb.Refreshing.Notifier}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
