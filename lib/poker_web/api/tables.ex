defmodule PokerWeb.Api.Tables do
  def list_tables() do
    Poker.Tables.list_tables()
  end

  def get_lobby(table_id) do
    Poker.Tables.get_lobby(table_id)
  end

  def create_table(%{user: user} = _scope, settings) do
    dbg(user)
    Poker.Tables.create_table(user.id, settings)
  end
end
