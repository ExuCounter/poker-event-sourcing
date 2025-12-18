defmodule Poker.Tables.Policy do
  @behaviour Bodyguard.Policy

  def authorize(:do, user, data) do
    :ok
  end
end
