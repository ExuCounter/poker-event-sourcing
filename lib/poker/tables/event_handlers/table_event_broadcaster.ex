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

  # Generic handler for all table events
  def handle(event, %{event_id: event_id})
      when is_map(event) and is_map_key(event, :table_id) and not is_nil(event_id) do
    event_name = derive_event_name(event)

    # Convert to map but keep __struct__ field and add event_id
    event_data =
      event
      |> Map.from_struct()
      |> Map.put(:__struct__, event.__struct__)
      |> Map.put(:event_id, event_id)

    Poker.TableEvents.broadcast_table(event.table_id, event_name, event_data)
    :ok
  end

  # Derive event name from struct module name
  # Example: Poker.Tables.Events.HandStarted -> :hand_started
  defp derive_event_name(event) do
    event.__struct__
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
    |> String.to_atom()
  end
end
