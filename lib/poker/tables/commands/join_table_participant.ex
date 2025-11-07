defmodule Poker.Tables.Commands.JoinTableParticipant do
  use Poker, :schema

  embedded_schema do
    field :participant_id, :binary_id
    field :player_id, :binary_id
    field :table_id, :binary_id
    field :chips, :integer
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> Ecto.Changeset.cast(attrs, [:participant_id, :player_id, :table_id, :chips])
    |> Ecto.Changeset.validate_required([:participant_id, :player_id, :table_id, :chips])
    |> Ecto.Changeset.validate_number(:chips, greater_than: 0)
  end
end
