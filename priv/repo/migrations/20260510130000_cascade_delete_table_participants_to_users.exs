defmodule Poker.Repo.Migrations.CascadeDeleteTableParticipantsToUsers do
  use Ecto.Migration

  def change do
    alter table(:table_participants) do
      modify :player_id,
             references(:users, type: :uuid, on_delete: :delete_all),
             from: references(:users, type: :uuid),
             null: false
    end
  end
end
