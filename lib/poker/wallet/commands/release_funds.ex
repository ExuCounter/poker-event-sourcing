defmodule Poker.Wallet.Commands.ReleaseFunds do
  use Poker, :schema

  embedded_schema do
    field :player_id, :binary_id
    field :game_id, :binary_id
    field :final_amount, :integer
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> Ecto.Changeset.cast(attrs, [:player_id, :game_id, :final_amount])
    |> Ecto.Changeset.validate_required([:player_id, :game_id, :final_amount])
    |> Ecto.Changeset.validate_number(:final_amount, greater_than_or_equal_to: 0)
  end
end
