defmodule PokerWeb.Api.Tables do
  def list_tables() do
    Poker.Tables.list_tables()
  end

  def get_lobby(table_id) do
    Poker.Tables.get_lobby(table_id)
  end

  def get_player_game_view(%{user: user} = _scope, table_id, since_version \\ nil) do
    Poker.Tables.get_player_game_view(table_id, user.id, since_version)
  end

  def create_table(%{user: user} = _scope, settings) do
    Poker.Tables.create_table(user.id, settings)
  end

  def join_participant(%{user: user} = _scope, %{table_id: table_id}) do
    Poker.Tables.join_participant(table_id, user.id)
  end

  def start_table(scope, table_id) do
    with :ok <- Poker.Tables.Policy.authorize(:start_table, scope, table_id) do
      Poker.Tables.start_table(table_id)
    end
  end

  # Player Actions

  def fold_hand(%{user: user} = _scope, table_id) do
    Poker.Tables.fold_hand(table_id, user.id)
  end

  def check_hand(%{user: user} = _scope, table_id) do
    Poker.Tables.check_hand(table_id, user.id)
  end

  def call_hand(%{user: user} = _scope, table_id) do
    Poker.Tables.call_hand(table_id, user.id)
  end

  def raise_hand(%{user: user} = _scope, table_id, amount) do
    Poker.Tables.raise_hand(table_id, user.id, amount)
  end

  def all_in_hand(%{user: user} = _scope, table_id) do
    Poker.Tables.all_in_hand(table_id, user.id)
  end
end
