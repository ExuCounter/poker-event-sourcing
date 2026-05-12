defmodule Poker.CashGames.PubSub do
  def subscribe_to_cash_games_list do
    Phoenix.PubSub.subscribe(Poker.PubSub, "cash_games_list")
  end

  def broadcast_cash_games_list(event, data \\ %{}) do
    Phoenix.PubSub.broadcast(
      Poker.PubSub,
      "cash_games_list",
      {:cash_games_list, event, data}
    )

    :ok
  end
end
