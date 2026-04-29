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
    * `opts` - Optional keyword list:
      * `:since_version` - Stream version for incremental updates
      * `:game_context` - Map with game type info (e.g. `%{type: :cash_game, min_buyin: 200, max_buyin: 2000}`)

  ## Returns

  A map containing:
    * `:table_status` - Current table status
    * `:total_pot` - Total chips in all pots
    * `:community_cards` - Cards on the board
    * `:participants` - List of all participants with their state
    * `:valid_actions` - Actions available to the current player
    * `:player_actions` - Meta-actions available (buy_in, sit_out, sit_in, leave)
  """
  def build(table_id, player_id, opts \\ []) do
    GameStateBuilder.build(table_id, player_id,
      since_version: Keyword.get(opts, :since_version),
      visibility_mode: :live,
      calculate_actions: true,
      game_context: Keyword.get(opts, :game_context)
    )
  end
end
