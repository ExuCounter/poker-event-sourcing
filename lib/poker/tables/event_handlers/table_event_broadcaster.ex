defmodule Poker.Tables.EventHandlers.TableEventBroadcaster do
  @moduledoc """
  Event handler that broadcasts table events to connected clients via PubSub.

  This module subscribes to all table events and broadcasts them to the appropriate
  topic for LiveView updates with event_id from metadata injected into the payload.
  """

  use Commanded.Event.Handler,
    application: Poker.App,
    name: __MODULE__,
    consistency: :strong

  alias PokerWeb.AnimationDelays

  # Generic handler for all table events
  def handle(event, %{event_id: event_id})
      when is_map(event) and is_map_key(event, :table_id) and not is_nil(event_id) do
    event_type = derive_event_type(event)

    # Convert to map but keep __struct__ field and add event_id
    event_data =
      event
      |> Map.from_struct()
      |> Map.put(:type, event_type)
      |> Map.put(:event_id, event_id)
      |> Map.put(:timing, %{
        duration: AnimationDelays.for_event(event)
      })

    Poker.TableEvents.broadcast_table(event.table_id, event_type, event_data)
    :ok
  end

  # Derive event name from struct module name
  # Example: Poker.Tables.Events.HandStarted -> :hand_started
  defp derive_event_type(event) do
    event.__struct__
    |> Module.split()
    |> List.last()
  end
end
