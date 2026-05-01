defmodule Poker.Wallet.Commands.TopUpReservation do
  use Poker, :schema

  embedded_schema do
    field :player_id, :binary_id
    field :game_id, :binary_id
    field :amount, :integer
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> Ecto.Changeset.cast(attrs, [:player_id, :game_id, :amount])
    |> Ecto.Changeset.validate_required([:player_id, :game_id, :amount])
    |> Ecto.Changeset.validate_number(:amount, greater_than: 0)
  end
end
