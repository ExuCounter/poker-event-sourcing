defmodule Poker.Repo.Migrations.AddCreatorIdToTableLobby do
  use Ecto.Migration

  def change do
    alter table("table_lobby") do
      add(:creator_id, :uuid, null: false)
    end
  end
end
