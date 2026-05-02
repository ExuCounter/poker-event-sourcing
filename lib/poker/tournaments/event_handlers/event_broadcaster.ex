defmodule Poker.Tournaments.EventHandlers.EventBroadcaster do
  @moduledoc """
  Event handler that broadcasts tournament events to connected clients via PubSub.

  Uses the Broadcastable protocol to determine which events should be broadcast.
  """

  use Commanded.Event.Handler,
    application: Poker.App,
    name: __MODULE__,
    consistency: :strong

  alias Poker.Events.Broadcastable
  alias Poker.Events.Transformer
  alias Poker.Tournaments.PubSub

  @list_events [
    Poker.Tournaments.Events.TournamentCreated,
    Poker.Tournaments.Events.TournamentFinished,
    Poker.Tournaments.Events.PlayerRegistered
  ]

  def handle(event, metadata) when is_map_key(event, :tournament_id) do
    case Broadcastable.for_broadcast(event) do
      {:broadcast, sanitized_data} ->
        transformed_event = Transformer.transform_sanitized(sanitized_data, event, metadata)

        PubSub.broadcast_tournament(
          event.tournament_id,
          transformed_event.type,
          transformed_event
        )

        if event.__struct__ in @list_events do
          PubSub.broadcast_tournament_list(transformed_event.type, transformed_event)
        end

      :skip ->
        :ok
    end
  end

  def handle(_event, _metadata), do: :ok
end
