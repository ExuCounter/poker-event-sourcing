defmodule Poker.Repo.Migrations.AddPositionToTableParticipantHands do
  use Ecto.Migration

  def change do
    execute(
      """
      CREATE TYPE participant_hand_position AS ENUM (
        'dealer',
        'small_blind',
        'big_blind',
        'utg',
        'utg_plus_1',
        'utg_plus_2',
        'lojack',
        'hijack',
        'cutoff'
      )
      """,
      "DROP TYPE participant_hand_position"
    )

    alter table(:table_participant_hands) do
      add :position, :participant_hand_position
    end

    create index(:table_participant_hands, [:position])
  end
end
