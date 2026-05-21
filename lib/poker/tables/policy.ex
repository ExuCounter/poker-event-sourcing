defmodule Poker.Tables.Policy do
  @behaviour Bodyguard.Policy

  alias Poker.Accounts

  def authorize(action, _scope, _params) when action in [:list_tables, :get_lobby], do: :ok

  def authorize(action, %{user: %{}}, _params)
      when action in [
             :get_player_game_view,
             :list_hand_history,
             :join_participant,
             :fold_hand,
             :check_hand,
             :call_hand,
             :raise_hand,
             :all_in_hand,
             :sit_out_participant,
             :sit_in_participant,
             :leave_table
           ],
      do: true

  def authorize(:create_table, %{user: user}, _params), do: not Accounts.guest?(user)
end
