defmodule Poker.Wallet.EventHandlers.EventBroadcaster do
  @moduledoc """
  Event handler that broadcasts wallet events to connected clients via PubSub.

  Uses the Broadcastable protocol to determine which events should be broadcast.
  """

  use Commanded.Event.Handler,
    application: Poker.App,
    name: __MODULE__,
    consistency: :strong

  alias Poker.Events.Broadcastable
  alias Poker.Events.Transformer
  alias Poker.Wallet.PubSub

  def handle(event, metadata) when not is_nil(event.player_id) do
    case Broadcastable.for_broadcast(event) do
      {:broadcast, sanitized_data} ->
        transformed_event = Transformer.transform_sanitized(sanitized_data, event, metadata)

        PubSub.broadcast_wallet(
          event.player_id,
          transformed_event.type,
          transformed_event
        )

      :skip ->
        :ok
    end
  end

  def handle(_event, _metadata), do: :ok
end
