defmodule PokerWeb.Api.Tables do
  def list_tables() do
    Poker.Tables.list_tables()
  end

  def get_lobby(table_id) do
    Poker.Tables.get_lobby(table_id)
  end

  def create_table(%{player: player} = _scope, settings) do
    dbg(player)
    Poker.Tables.create_table(player.id, settings)
  end
end
