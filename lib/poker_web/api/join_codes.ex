defmodule PokerWeb.Api.JoinCodes do
  @moduledoc """
  Resolves a join code to the lobby path of either a cash game or tournament.
  Codes are globally unique across both kinds (shared sequence), so the order
  of lookup is irrelevant for correctness.
  """

  use PokerWeb, :verified_routes

  def resolve(code) when is_binary(code) do
    case Poker.CashGames.get_cash_game_by_code(code) do
      {:ok, cash_game} ->
        {:ok, ~p"/cash/#{cash_game.table_id}/lobby"}

      {:error, _} ->
        case Poker.Tournaments.get_tournament_by_code(code) do
          {:ok, tournament} -> {:ok, ~p"/tournaments/#{tournament.id}/lobby"}
          {:error, _} -> {:error, :not_found}
        end
    end
  end
end
