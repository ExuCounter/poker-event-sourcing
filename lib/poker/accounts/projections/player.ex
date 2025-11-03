defmodule Poker.Accounts.Projections.Player do
  use Poker, :schema

  schema "players" do
    field(:email, :string)

    timestamps()
  end
end
