defmodule Poker.Tables.Views.PlayerGameView do
  @moduledoc """
  Builds a player-specific game view by replaying events from the event store.
  This eliminates the need for game state projections and frontend calculations.

  This module is now a thin wrapper around GameStateBuilder, configured
  specifically for live game play.
  """

  alias Poker.Tables.Views.GameStateBuilder

  @doc """
  Builds a complete player game view for a specific table and player.

  Configured for live game mode with:
  - Card visibility mode: :live (only show current player's cards)
  - Action calculation: enabled
  - Incremental updates: supported via since_version

  ## Parameters
    * `table_id` - The table identifier
    * `player_id` - The player for whom to build the view
    * `since_version` - Optional stream version of last processed event for incremental updates

  ## Returns

  A map containing:
    * `:table_status` - Current table status
    * `:hand_id` - Current hand identifier
    * `:total_pot` - Total chips in all pots
    * `:community_cards` - Cards on the board
    * `:hole_cards` - Current player's hole cards (opponent cards are hidden)
    * `:participants` - List of all participants with their state
    * `:valid_actions` - Actions available to the current player
    * `:latest_version` - Stream version of the latest processed event
    * `:new_events` - New events since `since_version` (for animation)
    * `:hand_status` - Current hand status (:pre_flop, :flop, etc.)
  """
  def build(table_id, player_id, since_version \\ nil) do
    GameStateBuilder.build(table_id, player_id,
      since_version: since_version,
      visibility_mode: :live,
      calculate_actions: true
    )
  end
end
