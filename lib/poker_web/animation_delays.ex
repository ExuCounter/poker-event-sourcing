defmodule PokerWeb.AnimationDelays do
  @moduledoc """
  Centralized animation delay configuration.
  """

  @action_bounce_duration 300
  @action_badge_duration 500
  @card_stagger 50
  @card_slide_in_duration 200
  @card_reveal_duration 200
  @card_deal_duration 500
  @card_deal_stagger 50
  @chip_appear_duration 50
  @chip_slide_duration 100
  @chip_stagger_per_player 100
  @chip_stagger_per_chip 50
  @showdown_glow_duration 1000
  @new_hand_glow_duration 1000

  @doc """
  Returns animation delay in milliseconds for an event.
  """
  def for_event(%Poker.Tables.Events.HandStarted{}), do: @new_hand_glow_duration

  def for_event(%Poker.Tables.Events.ParticipantHandGiven{}),
    do: @card_deal_duration + @card_deal_stagger

  # HandFinished with conditional logic based on reason
  def for_event(%Poker.Tables.Events.HandFinished{finish_reason: :all_folded}), do: 500
  def for_event(%Poker.Tables.Events.HandFinished{}), do: @showdown_glow_duration

  def for_event(%Poker.Tables.Events.ParticipantShowdownCardsRevealed{}),
    do: @card_reveal_duration

  # RoundStarted: card slide in + card stagger (3 cards max * 150ms)
  def for_event(%Poker.Tables.Events.RoundStarted{}),
    do: @card_slide_in_duration + @card_stagger * 3

  # Action events: bounce + badge display
  def for_event(%Poker.Tables.Events.ParticipantFolded{}),
    do: @action_bounce_duration + @action_badge_duration

  def for_event(%Poker.Tables.Events.ParticipantCalled{}),
    do: @action_bounce_duration + @action_badge_duration

  def for_event(%Poker.Tables.Events.ParticipantChecked{}),
    do: @action_bounce_duration + @action_badge_duration

  def for_event(%Poker.Tables.Events.ParticipantRaised{}),
    do: @action_bounce_duration + @action_badge_duration

  def for_event(%Poker.Tables.Events.ParticipantWentAllIn{}),
    do: @action_bounce_duration + @action_badge_duration

  # Blinds posting
  def for_event(%Poker.Tables.Events.SmallBlindPosted{}),
    do: @chip_appear_duration + @chip_stagger_per_chip * 3

  def for_event(%Poker.Tables.Events.BigBlindPosted{}),
    do: @chip_appear_duration + @chip_stagger_per_chip * 3

  # Pot recalculation with chip animations
  def for_event(%Poker.Tables.Events.PotsRecalculated{}),
    do: @chip_slide_duration + @chip_stagger_per_player * 6

  # Payout distribution
  def for_event(%Poker.Tables.Events.PayoutDistributed{}),
    do: @showdown_glow_duration

  def for_event(_), do: 0
end
