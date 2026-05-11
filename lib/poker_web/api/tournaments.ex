defmodule PokerWeb.Api.Tournaments do
  def list_tournaments do
    Poker.Tournaments.list_tournaments()
  end

  def get_tournament(tournament_id) do
    Poker.Tournaments.get_tournament(tournament_id)
  end

  def create_tournament(%{user: user} = scope, settings) do
    with :ok <-
           Bodyguard.permit(Poker.Tournaments.Policy, :create_tournament, scope, settings) do
      Poker.Tournaments.create_tournament(user.id, settings)
    end
  end

  def register_player(%{user: user} = scope, tournament_id) do
    with :ok <-
           Bodyguard.permit(Poker.Tournaments.Policy, :register_player, scope, tournament_id) do
      Poker.Tournaments.register_player(tournament_id, user.id)
    end
  end
end
