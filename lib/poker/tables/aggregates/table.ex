defmodule Poker.Tables.Aggregates.Table do
  alias Poker.Tables.Aggregates.Table

  alias Poker.Tables.Commands.{
    CreateTable,
    JoinTableParticipant,
    StartHand,
    GiveParticipantHand,
    StartTable
  }

  alias Poker.Tables.Events.{
    TableCreated,
    TableSettingsCreated,
    TableParticipantJoined,
    HandStarted,
    ParticipantHandGiven,
    TableStarted
  }

  defstruct [
    :id,
    :creator_id,
    :status,
    :settings,
    :participants,
    :hands
  ]

  def execute(
        %Table{} = _table,
        %CreateTable{
          table_id: table_id,
          creator_id: creator_id,
          creator_participant_id: creator_participant_id,
          settings: settings
        } =
          _event
      ) do
    [
      %TableCreated{
        id: table_id,
        creator_id: creator_id,
        status: :not_started
      },
      %TableSettingsCreated{
        id: settings.settings_id,
        table_id: table_id,
        big_blind: settings.big_blind,
        small_blind: settings.small_blind,
        starting_stack: settings.starting_stack,
        timeout_seconds: settings.timeout_seconds
      },
      %TableParticipantJoined{
        id: creator_participant_id,
        player_id: creator_id,
        table_id: table_id,
        chips: settings.starting_stack,
        seat_number: 1,
        status: :active
      }
    ]
  end

  def execute(%Table{participants: participants} = _table, %JoinTableParticipant{} = join) do
    seat_number = length(participants) + 1

    %TableParticipantJoined{
      id: join.participant_id,
      player_id: join.player_id,
      table_id: join.table_id,
      chips: join.chips,
      seat_number: seat_number,
      status: :active
    }
  end

  def execute(%Table{} = _table, %StartHand{} = start) do
    %HandStarted{
      id: start.hand_id,
      table_id: start.table_id,
      dealer_button_id: start.dealer_button_id,
      community_cards: []
    }
  end

  def execute(%Table{} = _table, %GiveParticipantHand{} = give) do
    %ParticipantHandGiven{
      id: give.participant_hand_id,
      table_id: give.table_id,
      participant_id: give.participant_id,
      table_hand_id: give.table_hand_id,
      hole_cards: give.hole_cards
    }
  end

  def execute(
        %Table{status: :not_started, id: table_id, participants: participants} = _table,
        %StartTable{
          hand_id: hand_id,
          dealer_button_id: dealer_button_id,
          dealt_cards: dealt_cards
        }
      ) do
    # Create participant hand events from dealt cards
    participant_hand_events =
      participants
      |> Enum.zip(dealt_cards)
      |> Enum.map(fn {participant, card_data} ->
        %ParticipantHandGiven{
          id: card_data.participant_hand_id,
          table_id: table_id,
          participant_id: participant.id,
          table_hand_id: hand_id,
          hole_cards: card_data.hole_cards
        }
      end)

    [
      %TableStarted{
        id: table_id,
        status: :live
      },
      %HandStarted{
        id: hand_id,
        table_id: table_id,
        dealer_button_id: dealer_button_id,
        community_cards: []
      }
    ] ++ participant_hand_events
  end

  def execute(%Table{status: status} = _table, %StartTable{}) when status != :not_started do
    {:error, :table_already_started}
  end

  # State mutators

  def apply(%Table{} = table, %TableSettingsCreated{} = created) do
    settings = %{
      id: created.id,
      table_id: created.table_id,
      small_blind: created.small_blind,
      big_blind: created.big_blind,
      starting_stack: created.starting_stack,
      timeout_seconds: created.timeout_seconds
    }

    %Table{table | settings: settings}
  end

  def apply(%Table{} = _table, %TableCreated{} = created) do
    %Table{
      id: created.id,
      creator_id: created.creator_id,
      status: created.status,
      participants: [],
      hands: []
    }
  end

  def apply(%Table{participants: participants} = table, %TableParticipantJoined{} = joined) do
    new_participant = %{
      id: joined.id,
      player_id: joined.player_id,
      chips: joined.chips,
      seat_number: joined.seat_number,
      status: joined.status
    }

    %Table{table | participants: participants ++ [new_participant]}
  end

  def apply(%Table{hands: hands} = table, %HandStarted{} = started) do
    new_hand = %{
      id: started.id,
      table_id: started.table_id,
      dealer_button_id: started.dealer_button_id,
      participant_hands: []
    }

    %Table{table | hands: hands ++ [new_hand]}
  end

  def apply(%Table{hands: hands} = table, %ParticipantHandGiven{} = given) do
    new_participant_hand = %{
      id: given.id,
      participant_id: given.participant_id,
      hole_cards: given.hole_cards
    }

    updated_hands =
      Enum.map(hands, fn hand ->
        if hand.id == given.table_hand_id do
          %{hand | participant_hands: hand.participant_hands ++ [new_participant_hand]}
        else
          hand
        end
      end)

    %Table{table | hands: updated_hands}
  end

  def apply(%Table{} = table, %TableStarted{} = started) do
    %Table{table | status: started.status}
  end
end
