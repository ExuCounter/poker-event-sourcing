defmodule Poker.Tables.EventHandlers.TableEventBroadcaster do
  @moduledoc """
  Event handler that broadcasts table events to connected clients via PubSub.

  This module subscribes to all table events and broadcasts them to the appropriate
  topic for LiveView updates. Uses EventTransformer for consistent event formatting.
  """

  use Commanded.Event.Handler,
    application: Poker.App,
    name: __MODULE__,
    consistency: :strong

  alias Poker.Tables.EventTransformer

  # Generic handler for all table events
  def handle(event, metadata)
      when is_map(event) and is_map_key(event, :table_id) and is_map_key(metadata, :event_id) do
    # Use EventTransformer for consistent formatting
    transformed_event = EventTransformer.transform(event, metadata)

    # Broadcast to PubSub
    Poker.TableEvents.broadcast_table(
      event.table_id,
      transformed_event.type,
      transformed_event
    )

    :ok
  end

  def handle(_, _), do: :ok
end
