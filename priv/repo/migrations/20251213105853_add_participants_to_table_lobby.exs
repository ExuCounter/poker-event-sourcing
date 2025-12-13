defmodule Poker.Repo.Migrations.AddParticipantsToTableLobby do
  use Ecto.Migration

  def change do
    alter table(:table_lobby) do
      add :participants, :jsonb, default: "[]", null: false
    end
  end
end
