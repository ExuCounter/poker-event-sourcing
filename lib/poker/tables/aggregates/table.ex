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
    SitInParticipant,
    StartRound
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
    RoundCompleted,
    PotsRecalculated
  }

  defstruct [
    :id,
    :creator_id,
    :status,
    :settings,
    :participants,
    :hand,
    :round,
    :community_cards,
    :pots,
    :participant_hands,
    positions: %{}
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
        timeout_seconds: settings.timeout_seconds,
        table_type: settings.table_type
      }
      # %TableParticipantJoined{
      #   id: creator_participant_id,
      #   player_id: creator_id,
      #   table_id: table_id,
      #   chips: settings.starting_stack,
      #   seat_number: 1,
      #   bet_this_round: 0,
      #   status: :active,
      #   is_sitting_out: false,
      #   total_bet_this_hand: 0
      # }
    ]
  end

  def execute(
        %Table{status: :live} = _table,
        %JoinTableParticipant{starting_stack: _starting_stack} = _join
      ) do
    {:error, :table_already_started}
  end

  def can_join?(%Table{participants: participants, settings: settings}) do
    max_players =
      case settings.table_type do
        :six_max -> 6
      end

    length(participants) < max_players
  end

  def can_start_table?(%Table{participants: participants, settings: settings}) do
    length(participants) >= 2
  end

  def execute(
        %Table{participants: participants, settings: settings} = table,
        %JoinTableParticipant{starting_stack: starting_stack} = join
      ) do
    table
    |> Commanded.Aggregate.Multi.new()
    |> Commanded.Aggregate.Multi.execute(fn _table ->
      if can_join?(_table) do
        :ok
      else
        {:error, :table_full}
      end
    end)
    |> Commanded.Aggregate.Multi.execute(fn _table ->
      seat_number = length(participants) + 1

      starting_stack =
        if is_nil(starting_stack) do
          starting_stack = settings.starting_stack
        else
          starting_stack
        end

      %TableParticipantJoined{
        id: join.participant_id,
        player_id: join.player_id,
        table_id: join.table_id,
        chips: starting_stack,
        initial_chips: starting_stack,
        seat_number: seat_number,
        is_sitting_out: false,
        bet_this_round: 0,
        total_bet_this_hand: 0,
        status: :active
      }
    end)
  end

  def execute(
        %Table{status: :not_started, id: table_id, participants: participants} = table,
        %StartTable{hand_id: hand_id} = _command
      ) do
    table
    |> Commanded.Aggregate.Multi.new()
    |> Commanded.Aggregate.Multi.execute(fn _table ->
      if can_start_table?(_table) do
        :ok
      else
        {:error, :not_enough_participants}
      end
    end)
    |> Commanded.Aggregate.Multi.execute(fn _table ->
      dealer_button_id = hd(participants).id

      %TableStarted{
        id: table_id,
        status: :live,
        hand_id: hand_id,
        dealer_button_id: dealer_button_id
      }
    end)
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
    active_participants = table.participants

    deck = generate_deck()

    participants_with_hole_cards_and_positions =
      active_participants
      |> Enum.with_index()
      |> Enum.map(fn {participant, index} ->
        cards = Enum.slice(deck, index * 2, 2)

        position =
          calculate_position(
            table.participants,
            dealer_button_participant.seat_number,
            participant.seat_number
          )

        {participant, cards, position}
      end)

    {small_blind_seat, big_blind_seat, utg_seat} =
      calculate_seats(active_participants, dealer_button_participant.seat_number)

    participant_with_small_blind = find_participant_by_seat(table, small_blind_seat)
    participant_with_big_blind = find_participant_by_seat(table, big_blind_seat)
    participant_to_act = find_participant_by_seat(table, utg_seat)

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
        type: :pre_flop,
        participant_to_act_id: participant_to_act.id,
        last_bet_amount: settings.big_blind,
        community_cards: []
      }
    end)
    |> Commanded.Aggregate.Multi.reduce(participants_with_hole_cards_and_positions, fn _table,
                                                                                       {participant,
                                                                                        hole_cards,
                                                                                        position} ->
      %ParticipantHandGiven{
        id: Ecto.UUID.generate(),
        table_id: table_id,
        participant_id: participant.id,
        table_hand_id: hand_id,
        hole_cards: hole_cards,
        position: position
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
        %Table{round: %{participant_to_act_id: participant_to_act_id}} = _table,
        %ParticipantActInHand{participant_id: participant_id} = _command
      )
      when participant_to_act_id != participant_id do
    {:error,
     %{
       status: :not_participants_turn,
       message: "It's not participant id:#{participant_id}'s turn to act"
     }}
  end

  def recalculate_pots(table) do
    unique_bet_amounts =
      table.participants
      |> Enum.map(& &1.total_bet_this_hand)
      |> Enum.filter(&(&1 > 0))
      |> Enum.uniq()
      |> Enum.sort()

    unique_bet_amounts
    |> Enum.reduce([], fn bet_amount, pots ->
      contributing_participants =
        table.participants |> Enum.filter(&(&1.total_bet_this_hand >= bet_amount))

      previous_bet_amount =
        case pots do
          [] -> 0
          _ -> pots |> List.last() |> Map.get(:bet_amount)
        end

      pot_amount =
        (bet_amount - previous_bet_amount) * length(contributing_participants)

      pots ++
        [
          %{
            bet_amount: bet_amount,
            amount: pot_amount,
            contributing_participant_ids: Enum.map(contributing_participants, & &1.id)
          }
        ]
    end)
    |> Enum.with_index()
    |> Enum.map(fn {pot, index} ->
      type = if index == 0, do: :main, else: :side
      Map.put(pot, :type, type)
    end)
  end

  def execute(
        %Table{
          hand: %{
            id: table_hand_id
          },
          round: %{
            id: round_id,
            type: round_type,
            last_bet_amount: last_bet_amount
          },
          participants: participants
        } = table,
        %ParticipantActInHand{} = command
      ) do
    participant = find_participant_by_id(table, command.participant_id)
    next_participant = find_next_participant(table)
    all_acted? = all_acted_before_current_participant?(table)

    table
    |> Commanded.Aggregate.Multi.new()
    |> Commanded.Aggregate.Multi.execute(fn _table ->
      case command.action do
        :raise ->
          if participant.chips < command.amount - participant.bet_this_round do
            {:error, :insufficient_chips}
          else
            :ok
          end

        :call ->
          call_amount =
            [last_bet_amount - participant.bet_this_round, participant.chips]
            |> Enum.filter(&(&1 >= 0))
            |> Enum.min()

          if participant.chips < call_amount do
            {:error, :insufficient_chips}
          else
            :ok
          end

        _ ->
          :ok
      end
    end)
    |> Commanded.Aggregate.Multi.execute(fn _table ->
      case command.action do
        :raise ->
          raise_amount = command.amount - participant.bet_this_round

          %ParticipantActedInHand{
            id: command.hand_action_id,
            participant_id: command.participant_id,
            table_hand_id: table_hand_id,
            action: command.action,
            amount: raise_amount,
            round: round_type,
            next_participant_to_act_id: next_participant.id
          }

        :call ->
          call_amount =
            [last_bet_amount - participant.bet_this_round, participant.chips]
            |> Enum.filter(&(&1 >= 0))
            |> Enum.min()

          %ParticipantActedInHand{
            id: command.hand_action_id,
            participant_id: command.participant_id,
            table_hand_id: table_hand_id,
            action: command.action,
            amount: call_amount,
            round: round_type,
            next_participant_to_act_id: next_participant.id
          }

        :fold ->
          %ParticipantActedInHand{
            id: command.hand_action_id,
            participant_id: command.participant_id,
            table_hand_id: table_hand_id,
            action: command.action,
            amount: 0,
            round: round_type,
            next_participant_to_act_id: next_participant.id
          }
      end
    end)
    |> Commanded.Aggregate.Multi.execute(fn table ->
      if all_acted? do
        [
          %RoundCompleted{
            id: round_id,
            hand_id: table_hand_id,
            type: round_type,
            table_id: table.id
          }
        ]
      else
        nil
      end
    end)
    |> Commanded.Aggregate.Multi.execute(fn _table ->
      recalculated_pots = recalculate_pots(table)

      %PotsRecalculated{
        table_id: table.id,
        hand_id: table_hand_id,
        pots: recalculate_pots(table)
      }
    end)
  end

  def execute(%Table{hand: nil} = _table, %ParticipantActInHand{}) do
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

  def execute(
        %Table{hand: %{id: hand_id}} = table,
        %StartRound{} = command
      )
      when hand_id == command.hand_id do
    active_participants = find_active_participants(table)
    dealer_button_participant = find_participant_by_id(table, table.hand.dealer_button_id)

    {_small_blind_seat, _big_blind_seat, utg_seat} =
      calculate_seats(active_participants, dealer_button_participant.seat_number)

    participant_to_act = find_participant_by_seat(table, utg_seat)
    deck = generate_deck()

    round_community_cards =
      case command.round do
        :flop ->
          Enum.slice(deck, 0, 3)

        :turn ->
          Enum.slice(deck, 3, 1)

        :river ->
          Enum.slice(deck, 4, 1)
      end

    %RoundStarted{
      id: command.round_id,
      hand_id: command.hand_id,
      type: command.round,
      participant_to_act_id: participant_to_act.id,
      last_bet_amount: 0,
      community_cards: round_community_cards
    }
  end

  def execute(%Table{hand: nil} = _table, %StartRound{}) do
    {:error, :no_active_hand}
  end

  def execute(%Table{hand: %{id: hand_id}} = _table, %StartRound{hand_id: command_hand_id})
      when hand_id != command_hand_id do
    {:error, :hand_id_mismatch}
  end

  # State mutators

  def apply(%Table{} = table, %TableSettingsCreated{} = created) do
    settings = %{
      id: created.id,
      small_blind: created.small_blind,
      big_blind: created.big_blind,
      starting_stack: created.starting_stack,
      timeout_seconds: created.timeout_seconds,
      table_type: created.table_type
    }

    %Table{table | settings: settings}
  end

  def apply(%Table{} = _table, %TableCreated{} = created) do
    %Table{
      id: created.id,
      creator_id: created.creator_id,
      status: created.status,
      participants: [],
      hand: nil,
      round: nil,
      participant_hands: []
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
          is_sitting_out: is_sitting_out,
          total_bet_this_hand: total_bet_this_hand,
          initial_chips: initial_chips
        } = _event
      ) do
    new_participant = %{
      id: id,
      player_id: player_id,
      chips: chips,
      seat_number: seat_number,
      status: status,
      bet_this_round: bet_this_round,
      is_sitting_out: is_sitting_out,
      total_bet_this_hand: total_bet_this_hand,
      initial_chips: initial_chips
    }

    %Table{table | participants: participants ++ [new_participant]}
  end

  def apply(%Table{} = table, %HandStarted{} = event) do
    hand = %{
      id: event.id,
      dealer_button_id: event.dealer_button_id
    }

    %Table{table | hand: hand, community_cards: [], participant_hands: []}
  end

  def apply(
        %Table{participant_hands: participant_hands} = table,
        %ParticipantHandGiven{} = event
      ) do
    new_participant_hand = %{
      id: event.id,
      participant_id: event.participant_id,
      hole_cards: event.hole_cards,
      position: event.position
    }

    %Table{table | participant_hands: participant_hands ++ [new_participant_hand]}
  end

  def apply(%Table{} = table, %TableStarted{} = event) do
    %Table{table | status: event.status}
  end

  def apply(
        %Table{round: round} = table,
        %ParticipantActedInHand{} = event
      ) do
    updated_round =
      round
      |> update_acted_participant_ids(event)
      |> update_participant_to_act_id(event)
      |> maybe_update_last_bet_amount(event)

    updated_participants =
      update_participant(
        table.participants,
        event.participant_id,
        &%{
          &1
          | chips: &1.chips - event.amount,
            bet_this_round: &1.bet_this_round + event.amount,
            total_bet_this_hand: &1.total_bet_this_hand + event.amount,
            status: if(event.action == :fold, do: :folded, else: &1.status)
        }
      )

    %Table{table | round: updated_round, participants: updated_participants}
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
        &%{
          &1
          | chips: &1.chips - event.amount,
            bet_this_round: event.amount,
            total_bet_this_hand: event.amount
        }
      )

    %Table{table | participants: updated_participants}
  end

  def apply(%Table{participants: participants} = table, %BigBlindPosted{} = event) do
    updated_participants =
      update_participant(
        participants,
        event.participant_id,
        &%{
          &1
          | chips: &1.chips - event.amount,
            bet_this_round: event.amount,
            total_bet_this_hand: event.amount
        }
      )

    %Table{table | participants: updated_participants}
  end

  def apply(%Table{} = table, %RoundCompleted{} = _event) do
    %Table{table | round: nil}
  end

  def apply(
        %Table{participants: participants, community_cards: community_cards} = table,
        %RoundStarted{} = event
      ) do
    round = %{
      id: event.id,
      type: event.type,
      participant_to_act_id: event.participant_to_act_id,
      last_bet_amount: event.last_bet_amount,
      acted_participant_ids: []
    }

    updated_community_cards = community_cards ++ event.community_cards
    updated_participants = Enum.map(participants, &%{&1 | bet_this_round: 0})

    %Table{
      table
      | participants: updated_participants,
        round: round,
        community_cards: updated_community_cards
    }
  end

  def apply(
        %Table{} = table,
        %PotsRecalculated{
          pots: pots
        } = _event
      ) do
    %Table{table | pots: pots}
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
        small_blind_seat = next_seat.(dealer_seat)
        big_blind_seat = next_seat.(small_blind_seat)
        utg_seat = next_seat.(big_blind_seat)

        {small_blind_seat, big_blind_seat, utg_seat}
    end
  end

  defp find_active_participants(%Table{participants: participants}) do
    Enum.filter(participants, &(&1.status == :active))
  end

  defp find_current_participant(%Table{
         participants: participants,
         round: %{participant_to_act_id: participant_to_act_id}
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
    acted_participant_ids = table.round.acted_participant_ids

    active_participants
    |> Enum.reject(fn participant -> participant.id == current_participant.id end)
    |> Enum.all?(fn participant -> participant.id in acted_participant_ids end)
  end

  defp calculate_position(participants, dealer_seat, participant_seat) do
    total_players = length(participants)

    # Find relative position from dealer (0 = dealer, 1 = next, etc.)
    relative_position = calculate_relative_position(dealer_seat, participant_seat, total_players)

    case total_players do
      2 -> calculate_heads_up_position(relative_position)
      3 -> calculate_three_handed_position(relative_position)
      4 -> calculate_four_handed_position(relative_position)
      5 -> calculate_five_handed_position(relative_position)
      6 -> calculate_six_handed_position(relative_position)
    end
  end

  defp calculate_relative_position(dealer_seat, participant_seat, total_players) do
    rem(participant_seat - dealer_seat + total_players, total_players)
  end

  # Heads up (2 players): Dealer is also SB, other is BB
  defp calculate_heads_up_position(0), do: :dealer
  defp calculate_heads_up_position(1), do: :big_blind

  # 3-handed: Dealer, SB, BB
  defp calculate_three_handed_position(0), do: :dealer
  defp calculate_three_handed_position(1), do: :small_blind
  defp calculate_three_handed_position(2), do: :big_blind

  # 4-handed: Dealer, SB, BB, CO
  defp calculate_four_handed_position(0), do: :dealer
  defp calculate_four_handed_position(1), do: :small_blind
  defp calculate_four_handed_position(2), do: :big_blind
  defp calculate_four_handed_position(3), do: :cutoff

  # 5-handed: Dealer, SB, BB, UTG, CO
  defp calculate_five_handed_position(0), do: :dealer
  defp calculate_five_handed_position(1), do: :small_blind
  defp calculate_five_handed_position(2), do: :big_blind
  defp calculate_five_handed_position(3), do: :utg
  defp calculate_five_handed_position(4), do: :cutoff

  # 6-handed: Dealer, SB, BB, UTG, HJ, CO
  defp calculate_six_handed_position(0), do: :dealer
  defp calculate_six_handed_position(1), do: :small_blind
  defp calculate_six_handed_position(2), do: :big_blind
  defp calculate_six_handed_position(3), do: :utg
  defp calculate_six_handed_position(4), do: :hijack
  defp calculate_six_handed_position(5), do: :cutoff
end
