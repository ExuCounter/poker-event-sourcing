defmodule Poker.Repo.Migrations.AddCodeToCashGames do
  use Ecto.Migration

  def change do
    alter table(:cash_games) do
      add :code, :string
    end

    create unique_index(:cash_games, [:code])
  end
end
