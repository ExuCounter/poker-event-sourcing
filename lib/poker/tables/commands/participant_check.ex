defmodule Poker.Tables.Commands.ParticipantCheck do
  use Poker, :schema

  embedded_schema do
    field :hand_action_id, :binary_id
    field :participant_id, :binary_id
    field :table_id, :binary_id
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> Ecto.Changeset.cast(attrs, [
      :hand_action_id,
      :participant_id,
      :table_id
    ])
    |> Ecto.Changeset.validate_required([
      :hand_action_id,
      :participant_id,
      :table_id
    ])
  end
end
