defmodule PokerWeb.Api.Tables do
  def list_tables() do
    Poker.Tables.list_tables()
  end

  def get_lobby(table_id) do
    Poker.Tables.get_lobby(table_id)
  end

  def get_table_state(%{user: user} = _scope, table_id) do
    Poker.Tables.get_table_state(table_id, user.id)
  end

  def create_table(%{user: user} = _scope, settings) do
    Poker.Tables.create_table(user.id, settings)
  end

  def join_participant(%{user: user} = _scope, %{table_id: table_id}) do
    Poker.Tables.join_participant(table_id, user.id)
  end

  def start_table(%{user: _user} = _scope, table_id) do
    Poker.Tables.start_table(table_id)
  end
end
