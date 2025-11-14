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
    BigBlindPosted,
    RoundStarted,
    RoundCompleted
  }

  defstruct [
    :id,
    :creator_id,
    :status,
    :settings,
    :participants,
    :current_hand,
    :current_round,
    :community_cards
  ]

  def execute(
        %Table{} = _table,
        %CreateTable{
          table_id: table_id,
          creator_id: creator_id,
          creator_participant_id: creator_participant_id,
          settings_id: settings_id,
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
        id: settings_id,
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
        bet_this_round: 0,
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
      bet_this_round: 0,
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
        %StartTable{hand_id: hand_id} = _command
      ) do
    dealer_button_id = hd(participants).id

    %TableStarted{
      id: table_id,
      status: :live,
      hand_id: hand_id,
      dealer_button_id: dealer_button_id
    }
  end

  def execute(%Table{status: status} = _table, %StartTable{}) when status != :not_started do
    {:error, :table_already_started}
  end

  def execute(
        %Table{id: table_id, settings: settings} = table,
        %StartHand{
          dealer_button_id: dealer_button_id,
          hand_id: hand_id
        }
      ) do
    dealer_button_participant = find_participant_by_id(table, dealer_button_id)
    active_participants = find_active_participants(table)

    deck = generate_deck()

    participants_with_hole_cards =
      active_participants
      |> Enum.with_index()
      |> Enum.map(fn {participant, index} ->
        cards = Enum.slice(deck, index * 2, 2)
        {participant, cards}
      end)

    {small_blind_seat, big_blind_seat, utg_seat} =
      calculate_seats(active_participants, dealer_button_participant.seat_number)

    participant_to_act = find_participant_by_seat(table, utg_seat)
    participant_with_small_blind = find_participant_by_seat(table, small_blind_seat)
    participant_with_big_blind = find_participant_by_seat(table, big_blind_seat)

    table
    |> Commanded.Aggregate.Multi.new()
    |> Commanded.Aggregate.Multi.execute(fn _table ->
      %HandStarted{
        id: hand_id,
        table_id: table_id,
        dealer_button_id: dealer_button_id
      }
    end)
    |> Commanded.Aggregate.Multi.execute(fn _table ->
      %RoundStarted{
        id: Ecto.UUID.generate(),
        hand_id: hand_id,
        round: :pre_flop,
        participant_to_act_id: participant_to_act.id,
        last_bet_amount: settings.big_blind
      }
    end)
    |> Commanded.Aggregate.Multi.reduce(participants_with_hole_cards, fn _table,
                                                                         {participant, hole_cards} ->
      %ParticipantHandGiven{
        id: Ecto.UUID.generate(),
        table_id: table_id,
        participant_id: participant.id,
        table_hand_id: hand_id,
        hole_cards: hole_cards
      }
    end)
    |> Commanded.Aggregate.Multi.execute(fn _table ->
      %BigBlindPosted{
        id: Ecto.UUID.generate(),
        table_id: table_id,
        hand_id: hand_id,
        participant_id: participant_with_big_blind.id,
        amount: settings.big_blind
      }
    end)
    |> Commanded.Aggregate.Multi.execute(fn _table ->
      %SmallBlindPosted{
        id: Ecto.UUID.generate(),
        table_id: table_id,
        hand_id: hand_id,
        participant_id: participant_with_small_blind.id,
        amount: settings.small_blind
      }
    end)
  end

  def execute(
        %Table{current_round: %{participant_to_act_id: participant_to_act_id}} = _table,
        %ParticipantActInHand{participant_id: participant_id} = _command
      )
      when participant_to_act_id != participant_id do
    {:error,
     %{
       status: :not_participants_turn,
       message: "It's not participant id:#{participant_id}'s turn to act"
     }}
  end

  def execute(
        %Table{
          current_hand: %{
            id: table_hand_id
          },
          current_round: %{
            id: round_id,
            round: current_round,
            last_bet_amount: last_bet_amount
          }
        } = table,
        %ParticipantActInHand{} = command
      ) do
    next_participant = find_next_participant(table)
    all_acted? = all_acted_before_current_participant?(table)

    acted_event =
      case command.action do
        :raise ->
          %ParticipantActedInHand{
            id: command.hand_action_id,
            participant_id: command.participant_id,
            table_hand_id: table_hand_id,
            action: command.action,
            amount: command.amount,
            round: current_round,
            next_participant_to_act_id: next_participant.id
          }

        :call ->
          %ParticipantActedInHand{
            id: command.hand_action_id,
            participant_id: command.participant_id,
            table_hand_id: table_hand_id,
            action: command.action,
            amount:
              last_bet_amount -
                find_participant_by_id(table, command.participant_id).bet_this_round,
            round: current_round,
            next_participant_to_act_id: next_participant.id
          }

        _ ->
          nil
      end

    if acted_event && all_acted? do
      [
        acted_event,
        %RoundCompleted{
          id: round_id,
          hand_id: table_hand_id,
          round: current_round
        }
      ]
    else
      acted_event
    end
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

  def apply(
        %Table{participants: participants} = table,
        %TableParticipantJoined{
          id: id,
          player_id: player_id,
          chips: chips,
          seat_number: seat_number,
          status: status,
          bet_this_round: bet_this_round,
          is_sitting_out: is_sitting_out
        } = _event
      ) do
    new_participant = %{
      id: id,
      player_id: player_id,
      chips: chips,
      seat_number: seat_number,
      status: status,
      bet_this_round: bet_this_round,
      is_sitting_out: is_sitting_out
    }

    %Table{table | participants: participants ++ [new_participant]}
  end

  def apply(%Table{} = table, %HandStarted{} = event) do
    current_hand = %{
      id: event.id,
      table_id: event.table_id,
      dealer_button_id: event.dealer_button_id,
      participant_hands: [],
      community_cards: []
    }

    %Table{table | current_hand: current_hand}
  end

  def apply(%Table{current_hand: current_hand} = table, %ParticipantHandGiven{} = event) do
    new_participant_hand = %{
      id: event.id,
      participant_id: event.participant_id,
      hole_cards: event.hole_cards
    }

    updated_hand = %{
      current_hand
      | participant_hands: current_hand.participant_hands ++ [new_participant_hand]
    }

    %Table{table | current_hand: updated_hand}
  end

  def apply(%Table{} = table, %TableStarted{} = event) do
    %Table{table | status: event.status}
  end

  def apply(
        %Table{current_round: current_round} = table,
        %ParticipantActedInHand{} = event
      ) do
    updated_round =
      current_round
      |> update_acted_participant_ids(event)
      |> update_participant_to_act_id(event)
      |> maybe_update_last_bet_amount(event)

    %Table{table | current_round: updated_round}
  end

  def apply(%Table{participants: participants} = table, %ParticipantSatOut{} = event) do
    updated_participants =
      update_participant(participants, event.participant_id, &%{&1 | is_sitting_out: true})

    %Table{table | participants: updated_participants}
  end

  def apply(%Table{participants: participants} = table, %ParticipantSatIn{} = event) do
    updated_participants =
      update_participant(participants, event.participant_id, &%{&1 | is_sitting_out: false})

    %Table{table | participants: updated_participants}
  end

  def apply(%Table{participants: participants} = table, %SmallBlindPosted{} = event) do
    updated_participants =
      update_participant(
        participants,
        event.participant_id,
        &%{&1 | chips: &1.chips - event.amount, bet_this_round: event.amount}
      )

    %Table{table | participants: updated_participants}
  end

  def apply(%Table{participants: participants} = table, %BigBlindPosted{} = event) do
    updated_participants =
      update_participant(
        participants,
        event.participant_id,
        &%{&1 | chips: &1.chips - event.amount, bet_this_round: event.amount}
      )

    %Table{table | participants: updated_participants}
  end

  def apply(%Table{} = table, %RoundCompleted{} = _event) do
    table
  end

  def apply(
        %Table{participants: participants} = table,
        %RoundStarted{} = event
      ) do
    current_round = %{
      id: event.id,
      round: event.round,
      participant_to_act_id: event.participant_to_act_id,
      last_bet_amount: event.last_bet_amount,
      acted_participant_ids: []
    }

    updated_participants = Enum.map(participants, &%{&1 | bet_this_round: 0})

    %Table{table | participants: updated_participants, current_round: current_round}
  end

  defp generate_deck do
    ranks = ~w(2 3 4 5 6 7 8 9 10 J Q K A)
    suits = ~w(hearts diamonds clubs spades)

    deck =
      for rank <- ranks, suit <- suits do
        %{rank: rank, suit: suit}
      end

    Enum.shuffle(deck)
  end

  defp update_participant_to_act_id(round, %ParticipantActedInHand{} = command) do
    %{round | participant_to_act_id: command.next_participant_to_act_id}
  end

  defp maybe_update_last_bet_amount(round, %ParticipantActedInHand{action: :raise} = command) do
    %{round | last_bet_amount: command.amount}
  end

  defp maybe_update_last_bet_amount(round, _command), do: round

  defp update_acted_participant_ids(
         round,
         %ParticipantActedInHand{action: action, participant_id: participant_id} = _command
       )
       when action in [:call, :raise] do
    %{round | acted_participant_ids: round.acted_participant_ids ++ [participant_id]}
  end

  defp update_acted_participant_ids(
         round,
         %ParticipantActedInHand{action: :fold, participant_id: participant_id} = _command
       ) do
    %{
      round
      | acted_participant_ids:
          Enum.reject(round.acted_participant_ids, fn id -> id == participant_id end)
    }
  end

  defp update_participant(participants, participant_id, fun) when is_function(fun, 1) do
    Enum.map(participants, fn
      %{id: ^participant_id} = participant ->
        fun.(participant)

      participant ->
        participant
    end)
  end

  defp next_seat(current_seat, total_seats) do
    rem(current_seat, total_seats) + 1
  end

  defp calculate_seats(participants, dealer_seat) do
    total = length(participants)
    next_seat = &next_seat(&1, total)

    case total do
      2 ->
        big_blind_seat = dealer_seat
        small_blind_seat = next_seat.(dealer_seat)
        utg_seat = next_seat.(small_blind_seat)

        {small_blind_seat, big_blind_seat, utg_seat}

      _ ->
        big_blind_seat = next_seat.(dealer_seat)
        small_blind_seat = next_seat.(big_blind_seat)
        utg_seat = next_seat.(small_blind_seat)

        {small_blind_seat, big_blind_seat, utg_seat}
    end
  end

  defp find_active_participants(%Table{participants: participants}) do
    Enum.filter(participants, &(&1.status == :active))
  end

  defp find_current_participant(%Table{
         participants: participants,
         current_round: %{participant_to_act_id: participant_to_act_id}
       }) do
    Enum.find(participants, &(&1.id == participant_to_act_id))
  end

  defp find_participant_by_id(%Table{participants: participants}, participant_id) do
    Enum.find(participants, &(&1.id == participant_id))
  end

  defp find_participant_by_seat(%Table{participants: participants}, seat_number) do
    Enum.find(participants, &(&1.seat_number == seat_number))
  end

  defp find_next_participant(table) do
    current_participant = find_current_participant(table)
    active_participants = find_active_participants(table)

    next_seat_number = next_seat(current_participant.seat_number, length(active_participants))

    find_participant_by_seat(table, next_seat_number)
  end

  defp all_acted_before_current_participant?(table) do
    current_participant = find_current_participant(table)
    active_participants = find_active_participants(table)
    acted_participant_ids = table.current_round.acted_participant_ids

    active_participants
    |> Enum.reject(fn participant -> participant.id == current_participant.id end)
    |> Enum.all?(fn participant -> participant.id in acted_participant_ids end)
  end
end
