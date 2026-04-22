defmodule Poker.Repo.Migrations.RemoveStatusFromCashGames do
  use Ecto.Migration

  def change do
    alter table(:cash_games) do
      remove :status, :string
    end
  end
end
