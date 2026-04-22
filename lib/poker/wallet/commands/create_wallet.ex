defmodule Poker.Wallet.Commands.CreateWallet do
  use Poker, :schema

  embedded_schema do
    field :player_id, :binary_id
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> Ecto.Changeset.cast(attrs, [:player_id])
    |> Ecto.Changeset.validate_required([:player_id])
  end
end
