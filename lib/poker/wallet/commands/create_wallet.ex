defmodule Poker.Wallet.Commands.CreateWallet do
  use Poker, :schema

  embedded_schema do
    field :player_id, :binary_id
    field :initial_balance, :integer, default: 0
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> Ecto.Changeset.cast(attrs, [:player_id, :initial_balance])
    |> Ecto.Changeset.validate_required([:player_id])
    |> Ecto.Changeset.validate_number(:initial_balance, greater_than_or_equal_to: 0)
  end
end
