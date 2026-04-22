defmodule PokerWeb.Api.CashGames do
  def list_cash_games() do
    Poker.CashGames.list_cash_games()
  end

  def get_cash_game(cash_game_id) do
    Poker.CashGames.get_cash_game(cash_game_id)
  end

  def create_cash_game(%{user: user} = _scope, settings) do
    Poker.CashGames.create_cash_game(user.id, settings)
  end

  def join_cash_game(%{user: user} = _scope, cash_game_id, buyin_amount) do
    Poker.CashGames.join_cash_game(cash_game_id, user.id, buyin_amount)
  end

  def leave_cash_game(%{user: user} = _scope, cash_game_id, final_chips) do
    Poker.CashGames.leave_cash_game(cash_game_id, user.id, final_chips)
  end

  def close_cash_game(_scope, cash_game_id) do
    Poker.CashGames.close_cash_game(cash_game_id)
  end
end
