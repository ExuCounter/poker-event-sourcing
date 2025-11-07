defmodule Poker.Tables.Commands.JoinTableParticipant do
  use Poker, :schema

  embedded_schema do
    field :participant_uuid, :binary_id
    field :player_uuid, :binary_id
    field :table_uuid, :binary_id
    field :chips, :integer
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> Ecto.Changeset.cast(attrs, [:participant_uuid, :player_uuid, :table_uuid, :chips])
    |> Ecto.Changeset.validate_required([:participant_uuid, :player_uuid, :table_uuid, :chips])
    |> Ecto.Changeset.validate_number(:chips, greater_than: 0)
  end
end
