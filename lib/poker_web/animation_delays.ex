defmodule PokerWeb.AnimationDelays do
  @moduledoc """
  Centralized animation delay configuration.

  Delays must exactly match frontend animation durations in:
  - assets/css/app.css (CSS animations)
  - assets/js/hooks.js (JS animation processing)
  """

  # Base animation durations from app.css
  # actionBounce animation
  @action_bounce_duration 600
  # fadeInOut for action badges
  @action_badge_duration 600
  # pulse animation
  @pulse_duration 600
  # glow animation
  @glow_duration 600
  # pot-update-pulse
  @pot_pulse_duration 400
  # delay between cards
  @card_stagger 150
  # showdown-highlight glow
  @showdown_glow_duration 3000
  # card reveal/unfold animation
  @card_reveal_duration 500

  @doc "Returns animation delay in milliseconds for an event module"
  @spec for_event(module()) :: non_neg_integer()
  def for_event(Poker.Tables.Events.HandStarted), do: @glow_duration
  def for_event(Poker.Tables.Events.HandFinished), do: @showdown_glow_duration
  def for_event(Poker.Tables.Events.ParticipantShowdownCardsRevealed), do: @card_reveal_duration

  # RoundStarted: pulse + card stagger (3 cards max * 150ms)
  def for_event(Poker.Tables.Events.RoundStarted),
    do: @pulse_duration + @card_stagger * 3

  # Action events: bounce + badge display
  def for_event(Poker.Tables.Events.ParticipantFolded),
    do: @action_bounce_duration + @action_badge_duration

  def for_event(Poker.Tables.Events.ParticipantCalled),
    do: @action_bounce_duration + @action_badge_duration

  def for_event(Poker.Tables.Events.ParticipantChecked),
    do: @action_bounce_duration + @action_badge_duration

  def for_event(Poker.Tables.Events.ParticipantRaised),
    do: @action_bounce_duration + @action_badge_duration

  def for_event(Poker.Tables.Events.ParticipantWentAllIn),
    do: 800 + @action_badge_duration

  def for_event(Poker.Tables.Events.PotsRecalculated), do: @pot_pulse_duration
  def for_event(_), do: 0

  @doc "Returns delay for event by string name (used in serialization)"
  @spec for_event_name(String.t()) :: non_neg_integer()
  def for_event_name(event_name) when is_binary(event_name) do
    module = Module.concat([Poker.Tables.Events, event_name])
    for_event(module)
  rescue
    ArgumentError -> 0
  end

  @doc "Returns true if event requires delayed LiveView update"
  @spec requires_delayed_update?(module()) :: boolean()
  def requires_delayed_update?(Poker.Tables.Events.HandFinished), do: true
  def requires_delayed_update?(Poker.Tables.Events.ParticipantFolded), do: true
  def requires_delayed_update?(Poker.Tables.Events.ParticipantCalled), do: true
  def requires_delayed_update?(Poker.Tables.Events.ParticipantChecked), do: true
  def requires_delayed_update?(Poker.Tables.Events.ParticipantRaised), do: true
  def requires_delayed_update?(Poker.Tables.Events.ParticipantWentAllIn), do: true
  def requires_delayed_update?(_), do: false

  @doc "Calculates maximum delay for a list of events"
  @spec max_delay_for_events([module()]) :: non_neg_integer()
  def max_delay_for_events(events) when is_list(events) do
    events
    |> Enum.map(&for_event/1)
    |> Enum.max(fn -> 0 end)
  end
end
