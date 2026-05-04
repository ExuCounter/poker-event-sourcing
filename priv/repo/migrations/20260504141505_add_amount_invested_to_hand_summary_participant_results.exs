defmodule Poker.Repo.Migrations.AddAmountInvestedToHandSummaryParticipantResults do
  use Ecto.Migration

  def change do
    alter table(:hand_summary_participant_results) do
      add :amount_invested, :integer, null: false, default: 0
    end
  end
end
