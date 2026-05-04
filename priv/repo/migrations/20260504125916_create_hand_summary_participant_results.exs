defmodule Poker.Repo.Migrations.CreateHandSummaryParticipantResults do
  use Ecto.Migration

  def change do
    create table(:hand_summary_participant_results, primary_key: false) do
      add :hand_id, :binary_id, null: false, primary_key: true
      add :player_id, :binary_id, null: false, primary_key: true
      add :amount_won, :integer, null: false, default: 0

      timestamps()
    end

    create index(:hand_summary_participant_results, [:player_id])
  end
end
