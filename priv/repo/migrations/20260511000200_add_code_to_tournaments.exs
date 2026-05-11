defmodule Poker.Repo.Migrations.AddCodeToTournaments do
  use Ecto.Migration

  def change do
    alter table(:tournaments) do
      add :code, :string
    end

    create unique_index(:tournaments, [:code])
  end
end
