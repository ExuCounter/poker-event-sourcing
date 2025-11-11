defmodule Poker.Repo.Migrations.AddParticipantToActIdToTableHands do
  use Ecto.Migration

  def change do
    alter table(:table_hands) do
      add :participant_to_act_id, references(:table_participants, type: :uuid, on_delete: :nilify_all)
    end

    create index(:table_hands, [:participant_to_act_id])
  end
end
