defmodule Poker.Tables.EventHandlers.EventBroadcaster do
  @moduledoc """
  Event handler that broadcasts table events to connected clients via PubSub.

  Uses the Broadcastable protocol to determine which events should be broadcast
  and to sanitize sensitive data before sending.
  """

  use Commanded.Event.Handler,
    application: Poker.App,
    name: __MODULE__,
    consistency: :strong

  alias Poker.Events.Broadcastable
  alias Poker.Events.Transformer

  def handle(event, metadata) when not is_nil(event.table_id) do
    case Broadcastable.for_broadcast(event) do
      {:broadcast, sanitized_data, timing} ->
        do_broadcast(event, metadata, sanitized_data, timing)

      {:broadcast, sanitized_data} ->
        do_broadcast(event, metadata, sanitized_data)

      :skip ->
        :ok
    end
  end

  def handle(_event, _metadata), do: :ok

  defp do_broadcast(event, metadata, sanitized_data, timing \\ nil) do
    transformed_event = Transformer.transform_sanitized(sanitized_data, event, metadata, timing)

    Poker.Tables.PubSub.broadcast_table(
      event.table_id,
      transformed_event.type,
      transformed_event
    )
  end
end
