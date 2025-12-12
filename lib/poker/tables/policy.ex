defmodule Poker.Tables.Policy do
  @behaviour Bodyguard.Policy

  def authorize(:do, user, data) do
    dbg(user)
    dbg(data)

    :ok
  end
end
