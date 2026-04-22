defmodule Poker.CashGames.Commands.CloseCashGame do
  use Poker, :schema

  embedded_schema do
    field :cash_game_id, :binary_id
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> Ecto.Changeset.cast(attrs, [:cash_game_id])
    |> Ecto.Changeset.validate_required([:cash_game_id])
  end
end
