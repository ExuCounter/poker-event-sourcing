defmodule Poker.CashGames.Policy do
  @moduledoc """
  Authorization policy for cash-game operations.
  """

  @behaviour Bodyguard.Policy

  alias Poker.Accounts

  def authorize(action, _scope, _params) when action in [:list_cash_games, :get_cash_game],
    do: :ok

  # Guests can join existing cash games but can't create them.
  def authorize(:create_cash_game, %{user: user}, _params), do: not Accounts.guest?(user)

  # Joining, buying in, and leaving are open to every authenticated player
  # (including guests). Listed explicitly so that a missing rule fails loudly
  # instead of being silently allowed.
  def authorize(:join_cash_game, %{user: %{}}, _args), do: true
  def authorize(:buy_in, %{user: %{}}, _args), do: true
  def authorize(:leave_cash_game, %{user: %{}}, _args), do: true

  # Only the creator may close their cash game.
  def authorize(:close_cash_game, %{user: user}, cash_game_id) do
    case Poker.CashGames.get_cash_game(cash_game_id) do
      {:ok, %{creator_id: creator_id}} -> creator_id == user.id
      _ -> false
    end
  end
end
