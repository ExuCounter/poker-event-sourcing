defmodule PokerWeb.PlayerLive.AnimationDelays do
  @moduledoc """
  Centralized animation delay configuration.
  Returns timing maps with duration (and optionally stagger) in milliseconds.
  """

  @action_bounce_duration 300
  @action_badge_duration 500
  @card_stagger 150
  @card_slide_in_duration 300
  @card_reveal_duration 1100
  @card_deal_duration 700
  @card_deal_stagger 150
  @chip_appear_duration 50
  @chip_slide_duration 220
  @chip_stagger_per_player 100
  @chip_stagger_per_chip 50
  @showdown_glow_duration 2000
  @new_hand_glow_duration 1000

  @doc """
  Returns timing map for an event. Includes duration and optionally stagger.
  """
  def for_event(%Poker.Tables.Events.HandStarted{}),
    do: %{duration: @new_hand_glow_duration}

  def for_event(%Poker.Tables.Events.ParticipantHandGiven{}),
    do: %{duration: @card_deal_duration, stagger: @card_deal_stagger}

  def for_event(%Poker.Tables.Events.HandFinished{finish_reason: :all_folded}),
    do: %{duration: 500}

  def for_event(%Poker.Tables.Events.HandFinished{}),
    do: %{duration: @showdown_glow_duration}

  def for_event(%Poker.Tables.Events.ParticipantShowdownCardsRevealed{}),
    do: %{duration: @card_reveal_duration}

  def for_event(%Poker.Tables.Events.RoundStarted{}),
    do: %{duration: @card_slide_in_duration, stagger: @card_stagger}

  def for_event(%Poker.Tables.Events.ParticipantFolded{}),
    do: %{duration: @action_bounce_duration + @action_badge_duration}

  def for_event(%Poker.Tables.Events.ParticipantCalled{}),
    do: %{duration: @action_bounce_duration + @action_badge_duration}

  def for_event(%Poker.Tables.Events.ParticipantChecked{}),
    do: %{duration: @action_bounce_duration + @action_badge_duration}

  def for_event(%Poker.Tables.Events.ParticipantRaised{}),
    do: %{duration: @action_bounce_duration + @action_badge_duration}

  def for_event(%Poker.Tables.Events.ParticipantWentAllIn{}),
    do: %{duration: @action_bounce_duration + @action_badge_duration}

  def for_event(%Poker.Tables.Events.SmallBlindPosted{}),
    do: %{duration: @chip_appear_duration + @chip_stagger_per_chip * 3}

  def for_event(%Poker.Tables.Events.BigBlindPosted{}),
    do: %{duration: @chip_appear_duration + @chip_stagger_per_chip * 3}

  def for_event(%Poker.Tables.Events.PotsRecalculated{}),
    do: %{duration: @chip_slide_duration + @chip_stagger_per_player * 6}

  def for_event(%Poker.Tables.Events.PayoutDistributed{}),
    do: %{duration: @showdown_glow_duration}

  def for_event(_), do: %{duration: 0}
end
