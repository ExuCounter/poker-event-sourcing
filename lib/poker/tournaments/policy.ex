defmodule Poker.Tournaments.Policy do
  @moduledoc """
  Authorization policy for tournament operations.
  """

  @behaviour Bodyguard.Policy

  alias Poker.Accounts

  def authorize(action, _scope, _params) when action in [:list_tournaments, :get_tournament],
    do: :ok

  # Creating tournaments is reserved for registered users.
  def authorize(:create_tournament, %{user: user}, _params), do: not Accounts.guest?(user)

  # Guests can register for any existing tournament.
  def authorize(:register_player, %{user: %{}}, _tournament_id), do: true
end
