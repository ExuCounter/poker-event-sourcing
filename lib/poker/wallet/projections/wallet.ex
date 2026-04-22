defmodule Poker.Wallet.Projections.Wallet do
  use Ecto.Schema

  @primary_key {:player_id, :binary_id, autogenerate: false}

  schema "wallets" do
    field :balance, :integer, default: 0
    field :reserved, :integer, default: 0

    timestamps()
  end
end
