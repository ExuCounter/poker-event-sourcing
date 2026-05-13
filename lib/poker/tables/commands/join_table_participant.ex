defmodule Poker.Tables.Commands.JoinTableParticipant do
  use Poker, :schema

  embedded_schema do
    field :player_id, :binary_id
    field :table_id, :binary_id
    field :participant_id, :binary_id
    field :starting_stack, :integer
    field :nickname, :string
    field :seat_number, :integer
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> Ecto.Changeset.cast(attrs, [
      :participant_id,
      :player_id,
      :table_id,
      :starting_stack,
      :nickname,
      :seat_number
    ])
    |> Ecto.Changeset.validate_required([:participant_id, :player_id, :table_id, :seat_number])
    |> Ecto.Changeset.validate_inclusion(:seat_number, 1..6)
  end
end
