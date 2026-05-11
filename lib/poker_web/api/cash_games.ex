defmodule PokerWeb.Api.CashGames do
  def list_cash_games() do
    Poker.CashGames.list_cash_games()
  end

  def get_cash_game(cash_game_id) do
    Poker.CashGames.get_cash_game(cash_game_id)
  end

  def create_cash_game(%{user: user} = scope, settings) do
    with :ok <- Bodyguard.permit(Poker.CashGames.Policy, :create_cash_game, scope, settings) do
      Poker.CashGames.create_cash_game(user.id, settings)
    end
  end

  def join_cash_game(%{user: user} = scope, cash_game_id, buyin_amount) do
    with :ok <-
           Bodyguard.permit(Poker.CashGames.Policy, :join_cash_game, scope, cash_game_id) do
      Poker.CashGames.join_cash_game(cash_game_id, user.id, buyin_amount)
    end
  end

  def buy_in(%{user: user} = scope, cash_game_id, amount) do
    with :ok <- Bodyguard.permit(Poker.CashGames.Policy, :buy_in, scope, cash_game_id) do
      Poker.CashGames.buy_in(cash_game_id, user.id, amount)
    end
  end

  def leave_cash_game(%{user: user} = scope, cash_game_id, final_chips) do
    with :ok <- Bodyguard.permit(Poker.CashGames.Policy, :leave_cash_game, scope, cash_game_id) do
      Poker.CashGames.leave_cash_game(cash_game_id, user.id, final_chips)
    end
  end

  def close_cash_game(scope, cash_game_id) do
    with :ok <-
           Bodyguard.permit(Poker.CashGames.Policy, :close_cash_game, scope, cash_game_id) do
      Poker.CashGames.close_cash_game(cash_game_id)
    end
  end
end
