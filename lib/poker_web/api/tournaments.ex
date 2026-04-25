defmodule PokerWeb.Api.Tournaments do
  def list_tournaments do
    Poker.Tournaments.list_tournaments()
  end

  def get_tournament(tournament_id) do
    Poker.Tournaments.get_tournament(tournament_id)
  end

  def create_tournament(%{user: user} = _scope, settings) do
    Poker.Tournaments.create_tournament(user.id, settings)
  end

  def register_player(%{user: user} = _scope, tournament_id) do
    Poker.Tournaments.register_player(tournament_id, user.id)
  end
end
