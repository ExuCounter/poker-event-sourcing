defmodule Poker.Tables.Aggregates.Table do
  alias Poker.Tables.Aggregates.Table

  alias Poker.Tables.Commands.{
    CreateTable,
    JoinTableParticipant,
    StartHand,
    GiveParticipantHand,
    StartTable,
    ParticipantActInHand,
    SitOutParticipant,
    SitInParticipant
  }

  alias Poker.Tables.Events.{
    TableCreated,
    TableSettingsCreated,
    TableParticipantJoined,
    HandStarted,
    ParticipantHandGiven,
    TableStarted,
    ParticipantActedInHand,
    ParticipantSatOut,
    ParticipantSatIn,
    SmallBlindPosted,
    BigBlindPosted
  }

  defstruct [
    :id,
    :creator_id,
    :status,
    :settings,
    :participants,
    :current_hand,
    :community_cards,
    :participant_to_act_id,
    :last_bet_amount,
    :acted_participant_ids
  ]

  def execute(
        %Table{} = _table,
        %CreateTable{
          table_id: table_id,
          creator_id: creator_id,
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
        id: Ecto.UUID.generate(),
        table_id: table_id,
        big_blind: settings.big_blind,
        small_blind: settings.small_blind,
        starting_stack: settings.starting_stack,
        timeout_seconds: settings.timeout_seconds
      },
      %TableParticipantJoined{
        id: Ecto.UUID.generate(),
        player_id: creator_id,
        table_id: table_id,
        chips: settings.starting_stack,
        seat_number: 1,
        status: :active
      }
    ]
  end

  def execute(
        %Table{participants: participants, settings: settings} = _table,
        %JoinTableParticipant{} = join
      ) do
    seat_number = length(participants) + 1

    %TableParticipantJoined{
      id: join.participant_id,
      player_id: join.player_id,
      table_id: join.table_id,
      chips: settings.starting_stack,
      seat_number: seat_number,
      status: :active
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
        %StartTable{}
      ) do
    dealer_button_id = hd(participants).id

    %TableStarted{
      id: table_id,
      status: :live,
      dealer_button_id: dealer_button_id
    }
  end

  def execute(%Table{status: status} = _table, %StartTable{}) when status != :not_started do
    {:error, :table_already_started}
  end

  def execute(
        %Table{participants: participants, id: table_id, settings: settings} = _table,
        %StartHand{
          dealer_button_id: dealer_button_id,
          hand_id: hand_id
        }
      ) do
    dealer_button_participant = Enum.find(participants, &(&1.id == dealer_button_id))
    active_participants = Enum.filter(participants, &(&1.status == :active))

    deck = generate_deck() |> Enum.shuffle()

    dealt_cards =
      active_participants
      |> Enum.with_index()
      |> Enum.map(fn {_participant, index} ->
        %{
          participant_hand_id: Ecto.UUID.generate(),
          hole_cards: Enum.slice(deck, index * 2, 2)
        }
      end)

    participant_hand_events =
      active_participants
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

    {small_blind_seat_number, big_blind_seat_number} =
      calculate_blind_seats(active_participants, dealer_button_participant.seat_number)

    small_blind_participant =
      Enum.find(active_participants, &(&1.seat_number == small_blind_seat_number))

    big_blind_participant = Enum.find(active_participants, &(&1.seat_number == big_blind_seat_number))

    [
      %HandStarted{
        id: hand_id,
        table_id: table_id,
        dealer_button_id: dealer_button_id
      }
    ] ++
      participant_hand_events ++
      [
        %SmallBlindPosted{
          id: Ecto.UUID.generate(),
          table_id: table_id,
          hand_id: hand_id,
          participant_id: small_blind_participant.id,
          amount: settings.small_blind
        },
        %BigBlindPosted{
          id: Ecto.UUID.generate(),
          table_id: table_id,
          hand_id: hand_id,
          participant_id: big_blind_participant.id,
          amount: settings.big_blind
        }
      ]
  end

  defp calculate_blind_seats(participants, dealer_seat) do
    total = length(participants)
    next_seat = &(rem(&1, total) + 1)

    case total do
      2 -> {dealer_seat, next_seat.(dealer_seat)}
      _ -> {next_seat.(dealer_seat), next_seat.(next_seat.(dealer_seat))}
    end
  end

  def execute(
        %Table{
          current_hand: %{id: table_hand_id, current_round: current_round},
          participants: participants
        } = _table,
        %ParticipantActInHand{} = command
      ) do
    amount =
      case command.action do
        :all_in ->
          participant = Enum.find(participants, &(&1.id == command.participant_id))
          participant.chips

        :call ->
          # TODO: Calculate from current bet and participant's contribution
          command.amount

        _ ->
          nil
      end

    %ParticipantActedInHand{
      id: command.hand_action_id,
      participant_id: command.participant_id,
      table_hand_id: table_hand_id,
      action: command.action,
      amount: amount,
      round: current_round
    }
  end

  def execute(%Table{current_hand: nil} = _table, %ParticipantActInHand{}) do
    {:error, :no_active_hand}
  end

  def execute(
        %Table{participants: participants} = _table,
        %SitOutParticipant{participant_id: participant_id} = command
      ) do
    participant = Enum.find(participants, &(&1.id == participant_id))

    if participant.is_sitting_out do
      {:error, :already_sat_out}
    else
      %ParticipantSatOut{
        participant_id: command.participant_id,
        table_id: command.table_id
      }
    end
  end

  def execute(
        %Table{participants: participants} = _table,
        %SitInParticipant{participant_id: participant_id} = command
      ) do
    participant = Enum.find(participants, &(&1.id == participant_id))

    if participant.is_sitting_out do
      %ParticipantSatIn{
        participant_id: command.participant_id,
        table_id: command.table_id
      }
    else
      {:error, :already_sat_in}
    end
  end

  def execute(%Table{} = _table, %SitInParticipant{} = command) do
    %ParticipantSatIn{
      participant_id: command.participant_id,
      table_id: command.table_id
    }
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
      current_hand: nil
    }
  end

  def apply(%Table{participants: participants} = table, %TableParticipantJoined{} = joined) do
    new_participant = %{
      id: joined.id,
      player_id: joined.player_id,
      chips: joined.chips,
      seat_number: joined.seat_number,
      status: joined.status,
      is_sitting_out: false
    }

    %Table{table | participants: participants ++ [new_participant]}
  end

  def apply(%Table{} = table, %HandStarted{} = started) do
    current_hand = %{
      id: started.id,
      table_id: started.table_id,
      dealer_button_id: started.dealer_button_id,
      participant_hands: [],
      community_cards: [],
      current_round: :pre_flop
    }

    %Table{table | current_hand: current_hand}
  end

  def apply(%Table{current_hand: current_hand} = table, %ParticipantHandGiven{} = given) do
    new_participant_hand = %{
      id: given.id,
      participant_id: given.participant_id,
      hole_cards: given.hole_cards
    }

    updated_hand = %{
      current_hand
      | participant_hands: current_hand.participant_hands ++ [new_participant_hand]
    }

    %Table{table | current_hand: updated_hand}
  end

  def apply(%Table{} = table, %TableStarted{} = started) do
    %Table{table | status: started.status}
  end

  def apply(%Table{} = table, %ParticipantActedInHand{} = _acted) do
    # Actions are tracked in projections, not in aggregate state
    table
  end

  def apply(%Table{participants: participants} = table, %ParticipantSatOut{} = event) do
    updated_participants =
      Enum.map(participants, fn participant ->
        if participant.id == event.participant_id do
          %{participant | is_sitting_out: true}
        else
          participant
        end
      end)

    %Table{table | participants: updated_participants}
  end

  def apply(%Table{participants: participants} = table, %ParticipantSatIn{} = event) do
    updated_participants =
      Enum.map(participants, fn participant ->
        if participant.id == event.participant_id do
          %{participant | is_sitting_out: false}
        else
          participant
        end
      end)

    %Table{table | participants: updated_participants}
  end

  def apply(%Table{participants: participants} = table, %SmallBlindPosted{} = event) do
    updated_participants =
      Enum.map(participants, fn participant ->
        if participant.id == event.participant_id do
          %{participant | chips: participant.chips - event.amount}
        else
          participant
        end
      end)

    %Table{table | participants: updated_participants}
  end

  def apply(%Table{participants: participants} = table, %BigBlindPosted{} = event) do
    updated_participants =
      Enum.map(participants, fn participant ->
        if participant.id == event.participant_id do
          %{participant | chips: participant.chips - event.amount}
        else
          participant
        end
      end)

    %Table{table | participants: updated_participants}
  end

  defp generate_deck do
    ranks = ~w(2 3 4 5 6 7 8 9 10 J Q K A)
    suits = ~w(hearts diamonds clubs spades)

    for rank <- ranks, suit <- suits do
      %{rank: rank, suit: suit}
    end
  end
end
