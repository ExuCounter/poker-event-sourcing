defmodule Poker.CashGames.EventHandlers.EventBroadcaster do
  @moduledoc """
  Event handler that broadcasts cash game events to connected clients via PubSub.

  Broadcasts to `table_list` topic so the dashboard picks up cash game
  lifecycle changes alongside table updates.
  """

  use Commanded.Event.Handler,
    application: Poker.App,
    name: __MODULE__,
    consistency: :strong

  alias Poker.Events.Broadcastable
  alias Poker.Events.Transformer

  def handle(event, metadata) when is_map_key(event, :cash_game_id) do
    case Broadcastable.for_broadcast(event) do
      {:broadcast, sanitized_data} ->
        transformed_event = Transformer.transform_sanitized(sanitized_data, event, metadata)
        Poker.Tables.PubSub.broadcast_table_list(event.cash_game_id, transformed_event.type, transformed_event)

      :skip ->
        :ok
    end
  end

  def handle(_event, _metadata), do: :ok
end
