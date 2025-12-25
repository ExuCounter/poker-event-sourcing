defmodule Poker.Tables.EventHandlers.TableEventBroadcaster do
  @moduledoc """
  Event handler that broadcasts table events to connected clients via PubSub.

  This module subscribes to all table events and broadcasts them to the appropriate
  topic for LiveView updates. This replaces the broadcasting logic that was previously
  scattered across multiple projectors.
  """

  use Commanded.Event.Handler,
    application: Poker.App,
    name: __MODULE__,
    consistency: :strong

  alias Poker.Tables.Events.{
    # Hand Events
    HandStarted,
    HandFinished,
    # Participant Hand Events
    ParticipantHandGiven,
    ParticipantFolded,
    ParticipantChecked,
    ParticipantCalled,
    ParticipantRaised,
    ParticipantWentAllIn,
    SmallBlindPosted,
    BigBlindPosted,
    # Round Events
    RoundStarted,
    RoundCompleted,
    ParticipantToActSelected,
    # Pot Events
    PotsRecalculated
  }

  # Hand Events

  def handle(%HandStarted{id: hand_id, table_id: table_id}, _metadata) do
    Poker.TableEvents.broadcast_table(table_id, :hand_started, %{hand_id: hand_id})
    :ok
  end

  def handle(
        %HandFinished{hand_id: hand_id, table_id: table_id, payouts: payouts},
        _metadata
      ) do
    Poker.TableEvents.broadcast_table(table_id, :hand_finished, %{
      hand_id: hand_id,
      payouts: payouts
    })

    :ok
  end

  # Participant Hand Events

  def handle(
        %ParticipantHandGiven{
          id: participant_hand_id,
          participant_id: participant_id,
          table_id: table_id,
          hole_cards: hole_cards,
          position: position,
          status: status
        },
        _metadata
      ) do
    Poker.TableEvents.broadcast_table(
      table_id,
      :participant_hand_given,
      %{
        id: participant_hand_id,
        participant_id: participant_id,
        hole_cards: hole_cards,
        position: position,
        status: status,
        bet_this_round: 0
      }
    )

    :ok
  end

  def handle(
        %ParticipantFolded{
          id: participant_hand_id,
          participant_id: participant_id,
          table_id: table_id,
          status: status
        },
        _metadata
      ) do
    Poker.TableEvents.broadcast_table(
      table_id,
      :participant_folded,
      %{
        id: participant_hand_id,
        participant_id: participant_id,
        status: status
      }
    )

    :ok
  end

  def handle(
        %ParticipantChecked{
          id: participant_hand_id,
          participant_id: participant_id,
          table_id: table_id
        },
        _metadata
      ) do
    Poker.TableEvents.broadcast_table(
      table_id,
      :participant_checked,
      %{
        id: participant_hand_id,
        participant_id: participant_id
      }
    )

    :ok
  end

  def handle(
        %ParticipantCalled{
          id: participant_hand_id,
          participant_id: participant_id,
          table_id: table_id,
          amount: amount
        },
        _metadata
      ) do
    Poker.TableEvents.broadcast_table(
      table_id,
      :participant_called,
      %{
        id: participant_hand_id,
        participant_id: participant_id,
        amount: amount
      }
    )

    :ok
  end

  def handle(
        %ParticipantRaised{
          id: participant_hand_id,
          participant_id: participant_id,
          table_id: table_id,
          amount: amount
        },
        _metadata
      ) do
    Poker.TableEvents.broadcast_table(
      table_id,
      :participant_raised,
      %{
        id: participant_hand_id,
        participant_id: participant_id,
        amount: amount
      }
    )

    :ok
  end

  def handle(
        %ParticipantWentAllIn{
          id: participant_hand_id,
          participant_id: participant_id,
          table_id: table_id,
          status: status,
          amount: amount
        },
        _metadata
      ) do
    Poker.TableEvents.broadcast_table(
      table_id,
      :participant_went_all_in,
      %{
        id: participant_hand_id,
        participant_id: participant_id,
        status: status,
        amount: amount
      }
    )

    :ok
  end

  def handle(
        %SmallBlindPosted{participant_id: participant_id, table_id: table_id, amount: amount},
        _metadata
      ) do
    Poker.TableEvents.broadcast_table(
      table_id,
      :small_blind_posted,
      %{
        participant_id: participant_id,
        amount: amount
      }
    )

    :ok
  end

  def handle(
        %BigBlindPosted{participant_id: participant_id, table_id: table_id, amount: amount},
        _metadata
      ) do
    Poker.TableEvents.broadcast_table(
      table_id,
      :big_blind_posted,
      %{
        participant_id: participant_id,
        amount: amount
      }
    )

    :ok
  end

  # Round Events

  def handle(
        %RoundStarted{id: round_id, table_id: table_id, community_cards: community_cards},
        _metadata
      ) do
    Poker.TableEvents.broadcast_table(table_id, :round_started, %{
      id: round_id,
      community_cards: community_cards
    })

    :ok
  end

  def handle(%RoundCompleted{id: round_id, table_id: table_id}, _metadata) do
    Poker.TableEvents.broadcast_table(table_id, :round_finished, %{
      id: round_id
    })

    :ok
  end

  def handle(
        %ParticipantToActSelected{
          table_id: table_id,
          round_id: round_id,
          participant_id: participant_id
        },
        _metadata
      ) do
    Poker.TableEvents.broadcast_table(table_id, :participant_to_act_selected, %{
      round_id: round_id,
      participant_id: participant_id
    })

    :ok
  end

  # Pot Events

  def handle(
        %PotsRecalculated{table_id: table_id, hand_id: hand_id, pots: pots},
        _metadata
      ) do
    Poker.TableEvents.broadcast_table(
      table_id,
      :pots_updated,
      %{
        hand_id: hand_id,
        pots:
          Enum.map(pots, fn pot ->
            %{
              id: pot.id,
              amount: pot.amount,
              type: pot.type
            }
          end)
      }
    )

    :ok
  end
end
