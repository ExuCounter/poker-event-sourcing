defmodule Poker.Accounts.Events.PlayerRegistered do
  @derive {Jason.Encoder, only: [:id, :email]}
  use Poker, :schema

  embedded_schema do
    field :email, :string
  end
end
