defmodule Poker.Repo.Migrations.CreateTableParticipantHandActions do
  use Ecto.Migration

  def change do
    # Create enum types
    execute(
      """
      CREATE TYPE hand_action_type AS ENUM ('fold', 'check', 'call', 'raise', 'all_in')
      """,
      "DROP TYPE hand_action_type"
    )

    execute(
      """
      CREATE TYPE hand_round AS ENUM ('pre_flop', 'flop', 'turn', 'river')
      """,
      "DROP TYPE hand_round"
    )

    create table(:table_participant_hand_actions, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :participant_id, references(:table_participants, type: :uuid, on_delete: :delete_all), null: false
      add :table_hand_id, references(:table_hands, type: :uuid, on_delete: :delete_all), null: false
      add :action, :hand_action_type, null: false
      add :amount, :integer
      add :round, :hand_round, null: false

      timestamps()
    end

    create index(:table_participant_hand_actions, [:participant_id])
    create index(:table_participant_hand_actions, [:table_hand_id])
    create index(:table_participant_hand_actions, [:round])
  end
end
