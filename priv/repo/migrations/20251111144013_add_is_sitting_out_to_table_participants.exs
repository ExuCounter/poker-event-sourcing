defmodule Poker.Repo.Migrations.AddIsSittingOutToTableParticipants do
  use Ecto.Migration

  def change do
    alter table(:table_participants) do
      add :is_sitting_out, :boolean, default: false, null: false
    end
  end
end
