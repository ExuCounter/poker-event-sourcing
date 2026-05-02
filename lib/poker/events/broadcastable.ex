defprotocol Poker.Events.Broadcastable do
  @moduledoc """
  Protocol for events that should be broadcast to LiveViews via PubSub.

  Returns:
  - `{:broadcast, sanitized_map, timing}` — broadcast with animation timing
  - `{:broadcast, sanitized_map}` — broadcast without animation (instant state update)
  - `:skip` — do not broadcast

  Events without an explicit implementation fall back to `:skip`,
  making "no broadcast" the safe default.
  """

  @fallback_to_any true
  def for_broadcast(event)
end

defimpl Poker.Events.Broadcastable, for: Any do
  def for_broadcast(_event), do: :skip
end
