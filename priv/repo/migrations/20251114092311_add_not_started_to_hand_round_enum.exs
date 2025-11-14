defmodule Poker.Repo.Migrations.AddNotStartedToHandRoundEnum do
  use Ecto.Migration

  def change do
    execute(
      """
        ALTER TYPE hand_round ADD VALUE IF NOT EXISTS 'not_started' BEFORE 'pre_flop'
      """,
      ""
    )

    alter table(:table_hands) do
      add :current_round, :hand_round, null: false
    end
  end
end
