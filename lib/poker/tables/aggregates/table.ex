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
    StartRound,
    FinishHand,
    FinishTable
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
    PotsRecalculated,
    DeckGenerated,
    DeckUpdated,
    ParticipantToActSelected,
    DealerButtonMoved,
    HandFinished,
    TableFinished,
    ParticipantBusted
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
    :remaining_deck,
    :dealer_button_id
  ]

  # COMMAND HANDLERS

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
    ]
  end

  def execute(
        %Table{status: :live} = _table,
        %JoinTableParticipant{starting_stack: _starting_stack} = _join
      ) do
    {:error, :table_already_started}
  end

  def execute(
        %Table{participants: participants, settings: settings} = table,
        %JoinTableParticipant{starting_stack: starting_stack} = join
      ) do
    max_players =
      case settings.table_type do
        :six_max -> 6
      end

    if length(participants) < max_players do
      seat_number = length(participants) + 1

      initial_chips =
        if is_nil(starting_stack) do
          starting_stack = settings.starting_stack
        else
          starting_stack
        end

      %TableParticipantJoined{
        id: join.participant_id,
        player_id: join.player_id,
        table_id: join.table_id,
        chips: initial_chips,
        initial_chips: initial_chips,
        seat_number: seat_number,
        is_sitting_out: false,
        bet_this_round: 0,
        total_bet_this_hand: 0,
        status: :active
      }
    else
      {:error, :table_full}
    end
  end

  def execute(
        %Table{status: :not_started, id: table_id, participants: participants} = table,
        %StartTable{} = _command
      ) do
    if length(participants) >= 2 do
      %TableStarted{
        id: table.id,
        status: :live
      }
    else
      {:error, :not_enough_participants}
    end
  end

  def execute(%Table{status: status} = _table, %StartTable{}) when status != :not_started do
    {:error, :table_already_started}
  end

  def execute(%Table{} = table, %StartHand{hand_id: hand_id} = event) do
    active_participants = filter_active_participants(table.participants)

    if length(active_participants) >= 2 do
      start_hand(table, hand_id)
    else
      %TableFinished{
        table_id: table.id,
        reason: :completed
      }
    end
  end

  def execute(
        %Table{id: table_id, settings: settings, participants: participants} = table,
        %StartHand{hand_id: hand_id}
      ) do
    active_participants = filter_active_participants(participants)

    table
    |> Commanded.Aggregate.Multi.new()
    |> Commanded.Aggregate.Multi.execute(fn table ->
      shuffled_deck = Poker.Services.Deck.generate_deck() |> Poker.Services.Deck.shuffle_deck()

      %DeckGenerated{
        hand_id: hand_id,
        table_id: table_id,
        cards: shuffled_deck
      }
    end)
    |> Commanded.Aggregate.Multi.execute(fn table ->
      dealer_button_participant = find_dealer_button_participant(table)

      %DealerButtonMoved{
        table_id: table_id,
        hand_id: hand_id,
        participant_id: dealer_button_participant.id
      }
    end)
    |> Commanded.Aggregate.Multi.execute(fn table ->
      %HandStarted{
        id: hand_id,
        table_id: table_id
      }
    end)
    |> Commanded.Aggregate.Multi.execute(fn table ->
      %RoundStarted{
        id: Ecto.UUID.generate(),
        hand_id: hand_id,
        type: :pre_flop,
        last_bet_amount: settings.big_blind,
        community_cards: []
      }
    end)
    |> Commanded.Aggregate.Multi.reduce(active_participants, fn table, participant ->
      {hole_cards, remaining_deck} = Poker.Services.Deck.pick_cards(table.remaining_deck, 2)

      position = calculate_position(table, participant)

      [
        %ParticipantHandGiven{
          id: Ecto.UUID.generate(),
          table_id: table_id,
          participant_id: participant.id,
          table_hand_id: hand_id,
          hole_cards: hole_cards,
          position: position,
          status: :playing
        },
        %DeckUpdated{
          hand_id: hand_id,
          table_id: table_id,
          cards: remaining_deck
        }
      ]
    end)
    |> Commanded.Aggregate.Multi.execute(fn table ->
      if heads_up?(table) do
        hand = find_participant_hand_by_position(table, :dealer)

        %SmallBlindPosted{
          id: Ecto.UUID.generate(),
          table_id: table.id,
          hand_id: hand_id,
          participant_id: hand.participant_id,
          amount: settings.small_blind
        }
      else
        hand = find_participant_hand_by_position(table, :small_blind)

        %SmallBlindPosted{
          id: Ecto.UUID.generate(),
          table_id: table.id,
          hand_id: hand_id,
          participant_id: hand.participant_id,
          amount: settings.small_blind
        }
      end
    end)
    |> Commanded.Aggregate.Multi.execute(fn table ->
      hand = find_participant_hand_by_position(table, :big_blind)

      %BigBlindPosted{
        id: Ecto.UUID.generate(),
        table_id: table.id,
        hand_id: hand_id,
        participant_id: hand.participant_id,
        amount: settings.big_blind
      }
    end)
    |> Commanded.Aggregate.Multi.execute(fn table ->
      participant_to_act = find_participant_to_act(table)

      %ParticipantToActSelected{
        table_id: table_id,
        hand_id: hand_id,
        participant_id: participant_to_act.id
      }
    end)
    |> Commanded.Aggregate.Multi.execute(fn table ->
      recalculated_pots = recalculate_pots(table)

      %PotsRecalculated{
        table_id: table.id,
        hand_id: hand_id,
        pots: recalculate_pots(table)
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

  def act(table, %{action: :raise} = command) do
    participant = find_participant_to_act(table)
    raise_amount = command.amount - participant.bet_this_round

    if participant.chips < raise_amount do
      {:error, :insufficient_chips}
    else
      %ParticipantActedInHand{
        id: command.hand_action_id,
        participant_id: command.participant_id,
        table_hand_id: table.hand.id,
        action: command.action,
        amount: raise_amount,
        round: table.round.type
      }
    end
  end

  def act(table, %{action: :call} = command) do
    participant = find_participant_to_act(table)
    last_bet_amount = table.round.last_bet_amount

    call_amount =
      [last_bet_amount - participant.bet_this_round, participant.chips]
      |> Enum.filter(&(&1 >= 0))
      |> Enum.min()

    if participant.chips < call_amount do
      {:error, :insufficient_chips}
    else
      %ParticipantActedInHand{
        id: command.hand_action_id,
        participant_id: command.participant_id,
        table_hand_id: table.hand.id,
        action: command.action,
        amount: call_amount,
        round: table.round.type
      }
    end
  end

  def act(table, %{action: :all_in} = command) do
    participant = find_participant_to_act(table)

    %ParticipantActedInHand{
      id: command.hand_action_id,
      participant_id: command.participant_id,
      table_hand_id: table.hand.id,
      action: command.action,
      amount: participant.chips,
      round: table.round.type
    }
  end

  def act(table, %{action: :fold} = command) do
    %ParticipantActedInHand{
      id: command.hand_action_id,
      participant_id: command.participant_id,
      table_hand_id: table.hand.id,
      action: command.action,
      amount: 0,
      round: table.round.type
    }
  end

  def act(_table, _command), do: :ok

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
    table
    |> Commanded.Aggregate.Multi.new()
    |> Commanded.Aggregate.Multi.execute(&act(&1, command))
    |> Commanded.Aggregate.Multi.execute(fn table ->
      next_participant = find_next_participant_to_act(table)

      %ParticipantToActSelected{
        table_id: table.id,
        hand_id: table_hand_id,
        participant_id: next_participant.id
      }
    end)
    |> Commanded.Aggregate.Multi.execute(fn table ->
      recalculated_pots = recalculate_pots(table)

      %PotsRecalculated{
        table_id: table.id,
        hand_id: table_hand_id,
        pots: recalculate_pots(table)
      }
    end)
    |> Commanded.Aggregate.Multi.execute(fn table ->
      all_acted? = all_acted?(table)

      if all_acted? do
        %RoundCompleted{
          id: round_id,
          hand_id: table_hand_id,
          type: round_type,
          table_id: table.id
        }
      else
        :ok
      end
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
      %ParticipantSatIn{participant_id: command.participant_id, table_id: command.table_id}
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

  def execute(%Table{hand: %{id: hand_id}} = _table, %StartRound{hand_id: command_hand_id})
      when hand_id != command_hand_id do
    {:error, :hand_id_mismatch}
  end

  def execute(%Table{hand: %{id: hand_id}} = table, %StartRound{} = command) do
    if runout?(table) do
      table
      |> Commanded.Aggregate.Multi.new()
      |> Commanded.Aggregate.Multi.execute(&start_round(&1, command))
      |> Commanded.Aggregate.Multi.execute(fn table ->
        %RoundCompleted{
          id: table.round.id,
          hand_id: table.hand.id,
          type: table.round.type,
          table_id: table.id
        }
      end)
    else
      start_round(table, command)
    end
  end

  def execute(
        %Table{
          hand: %{id: hand_id},
          pots: pots,
          participant_hands: participant_hands,
          community_cards: community_cards
        } = table,
        %FinishHand{
          hand_id: command_hand_id,
          table_id: table_id,
          finish_reason: finish_reason
        } = _command
      ) do
    table
    |> Commanded.Aggregate.Multi.new()
    |> Commanded.Aggregate.Multi.execute(fn %{
                                              hand: %{id: hand_id},
                                              pots: pots,
                                              participant_hands: participant_hands,
                                              community_cards: community_cards
                                            } ->
      payouts =
        Enum.reduce(pots, [], fn pot, acc ->
          contributing_participant_hands =
            participant_hands
            |> Enum.filter(&(&1.participant_id in pot.contributing_participant_ids))

          winners =
            Poker.Services.HandEvaluator.determine_winners(
              contributing_participant_hands,
              community_cards
            )

          payouts =
            Enum.map(
              winners,
              &%{
                participant_id: &1.participant_id,
                amount: pot.amount,
                hand_rank: &1.hand_rank
              }
            )

          acc ++ payouts
        end)

      %HandFinished{
        table_id: table_id,
        hand_id: hand_id,
        finish_reason: finish_reason,
        payouts: payouts
      }
    end)
    |> Commanded.Aggregate.Multi.execute(fn table ->
      busted_participants =
        Enum.filter(table.participants, fn participant -> participant.chips == 0 end)

      Enum.map(busted_participants, fn participant ->
        %ParticipantBusted{
          participant_id: participant.id,
          hand_id: table.hand.id,
          table_id: table.id
        }
      end)
    end)
  end

  def execute(%Table{hand: nil} = _table, %FinishHand{}) do
    {:error, :no_active_hand}
  end

  def execute(%Table{hand: %{id: hand_id}} = _table, %FinishHand{hand_id: command_hand_id})
      when hand_id != command_hand_id do
    {:error, :hand_id_mismatch}
  end

  def execute(%Table{id: table_id} = _table, %FinishTable{table_id: table_id, reason: reason}) do
    %TableFinished{
      table_id: table_id,
      reason: reason
    }
  end

  # STATE MUTATORS

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
    hand = %{id: event.id}

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
      position: event.position,
      status: event.status
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
      |> maybe_update_last_bet_amount(event)

    updated_participants =
      update_participant(
        table,
        event.participant_id,
        &%{
          &1
          | chips: &1.chips - event.amount,
            bet_this_round: &1.bet_this_round + event.amount,
            total_bet_this_hand: &1.total_bet_this_hand + event.amount,
            status: if(event.action == :fold, do: :folded, else: &1.status)
        }
      )

    updated_participant_hands =
      update_participant_hand(
        table,
        event.participant_id,
        fn hand ->
          participant = find_participant_by_id(table, event.participant_id)

          %{
            hand
            | status:
                cond do
                  participant.chips == 0 -> :all_in
                  event.action == :all_in -> :all_in
                  event.action == :fold -> :folded
                  true -> :playing
                end
          }
        end
      )

    %Table{
      table
      | round: updated_round,
        participants: updated_participants,
        participant_hands: updated_participant_hands
    }
  end

  def apply(%Table{} = table, %ParticipantSatOut{} = event) do
    updated_participants =
      update_participant(table, event.participant_id, &%{&1 | is_sitting_out: true})

    %Table{table | participants: updated_participants}
  end

  def apply(%Table{} = table, %ParticipantSatIn{} = event) do
    updated_participants =
      update_participant(table, event.participant_id, &%{&1 | is_sitting_out: false})

    %Table{table | participants: updated_participants}
  end

  def apply(%Table{} = table, %SmallBlindPosted{} = event) do
    updated_participants =
      update_participant(
        table,
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

  def apply(%Table{} = table, %BigBlindPosted{} = event) do
    updated_participants =
      update_participant(
        table,
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

  def apply(%Table{} = table, %RoundCompleted{} = event) do
    table
  end

  def apply(
        %Table{participants: participants, community_cards: community_cards} = table,
        %RoundStarted{} = event
      ) do
    round = %{
      id: event.id,
      type: event.type,
      last_bet_amount: event.last_bet_amount,
      acted_participant_ids: [],
      participant_to_act_id: nil
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

  def apply(%Table{} = table, %DeckGenerated{} = event) do
    %Table{table | remaining_deck: event.cards}
  end

  def apply(%Table{} = table, %DeckUpdated{} = event) do
    %Table{table | remaining_deck: event.cards}
  end

  def apply(%Table{round: round} = table, %ParticipantToActSelected{} = event) do
    %Table{table | round: %{round | participant_to_act_id: event.participant_id}}
  end

  def apply(%Table{} = table, %DealerButtonMoved{} = event) do
    %Table{table | dealer_button_id: event.participant_id}
  end

  def apply(
        %Table{} = table,
        %PotsRecalculated{
          pots: pots
        } = _event
      ) do
    %Table{table | pots: pots}
  end

  def apply(%Table{} = table, %HandFinished{payouts: payouts} = event) do
    updated_participants =
      Enum.map(table.participants, fn participant ->
        payout = Enum.find(payouts, &(&1.participant_id == participant.id))

        if payout do
          %{participant | chips: participant.chips + payout.amount}
        else
          participant
        end
      end)

    %Table{table | participants: updated_participants}
  end

  def apply(%Table{} = table, %ParticipantBusted{participant_id: participant_id} = _event) do
    updated_participants =
      update_participant(table, participant_id, &%{&1 | status: :busted})

    %Table{table | participants: updated_participants}
  end

  def apply(%Table{} = table, %TableFinished{reason: reason} = _event) do
    %Table{table | status: :finished}
  end

  # HELPER FUNCTIONS

  defp maybe_update_last_bet_amount(round, %ParticipantActedInHand{action: action} = command)
       when action in [:raise, :all_in] do
    %{round | last_bet_amount: command.amount}
  end

  defp maybe_update_last_bet_amount(round, _command), do: round

  defp update_acted_participant_ids(
         round,
         %ParticipantActedInHand{action: action, participant_id: participant_id} = _command
       ) do
    %{round | acted_participant_ids: round.acted_participant_ids ++ [participant_id]}
  end

  defp update_participant(table, participant_id, fun) when is_function(fun, 1) do
    Enum.map(table.participants, fn
      %{id: ^participant_id} = participant ->
        fun.(participant)

      participant ->
        participant
    end)
  end

  defp update_participant_hand(table, participant_id, fun) when is_function(fun, 1) do
    Enum.map(table.participant_hands, fn
      %{participant_id: ^participant_id} = participant_hand ->
        fun.(participant_hand)

      participant_hand ->
        participant_hand
    end)
  end

  defp next_seat(current_seat, total_seats) do
    rem(current_seat, total_seats) + 1
  end

  defp find_dealer_button_participant(table) do
    if is_nil(table.dealer_button_id) do
      hd(table.participants)
    else
      dealer_button_participant = find_participant_by_id(table, table.dealer_button_id)
      seat_number = next_seat(dealer_button_participant.seat_number, length(table.participants))

      find_participant_by_seat(table, seat_number)
    end
  end

  defp filter_active_participants(participants) do
    Enum.filter(participants, &(&1.status == :active))
  end

  defp find_participant_to_act(
         %Table{round: %{type: :pre_flop, acted_participant_ids: []}} = table
       ) do
    big_blind_participant = find_participant_by_position(table, :big_blind)
    active_participants = filter_active_participants(table.participants)

    seat_number = next_seat(big_blind_participant.seat_number, length(table.participants))

    find_participant_by_seat(table, seat_number)
  end

  defp find_participant_to_act(%Table{
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

  defp find_next_participant_to_act(table) do
    participant_to_act = find_participant_to_act(table)
    active_participants = filter_active_participants(table.participants)

    next_participant_to_act_seat_number =
      next_seat(participant_to_act.seat_number, length(active_participants))

    find_participant_by_seat(table, next_participant_to_act_seat_number)
  end

  defp all_acted?(table) do
    acted_participant_ids = table.round.acted_participant_ids

    table.participants |> Enum.all?(fn participant -> participant.id in acted_participant_ids end)
  end

  defp calculate_position(table, participant) do
    total_players = length(table.participants)
    dealer_participant = find_participant_by_id(table, table.dealer_button_id)

    # Find relative position from dealer (0 = dealer, 1 = next, etc.)
    relative_position =
      calculate_relative_position(
        dealer_participant.seat_number,
        participant.seat_number,
        total_players
      )

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

  defp suit_abbreviation(suit) do
    %{hearts: :h, diamonds: :d, clubs: :c, spades: :s} |> Map.get(suit)
  end

  defp format_to_tuple(cards) do
    cards
    |> Enum.map(fn card -> {card.rank, suit_abbreviation(card.suit)} end)
    |> List.to_tuple()
  end

  defp recalculate_pots(table) do
    unique_bet_amounts =
      table.participants
      |> Enum.map(& &1.total_bet_this_hand)
      |> Enum.filter(&(&1 > 0))
      |> Enum.uniq()
      |> Enum.sort()

    unique_bet_amounts
    |> Enum.reduce([], fn bet_amount, pots ->
      contributing_participants =
        table.participants
        |> Enum.filter(&(&1.total_bet_this_hand >= bet_amount))
        |> filter_active_participants()

      previous_bet_amount =
        if pots == [] do
          0
        else
          pots |> List.last() |> Map.get(:bet_amount)
        end

      bet_amount = bet_amount - previous_bet_amount
      pot_amount = bet_amount * length(contributing_participants)

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

  defp heads_up?(table) do
    length(table.participant_hands) == 2
  end

  defp runout?(table) do
    Enum.all?(table.participant_hands, fn hand -> hand.status == :all_in end)
  end

  defp find_participant_hand_by_position(table, position) do
    Enum.find(table.participant_hands, &(&1.position == position))
  end

  defp find_participant_by_position(table, position) do
    hand = find_participant_hand_by_position(table, position)
    find_participant_by_id(table, hand.participant_id)
  end

  defp start_hand(
         %Table{id: table_id, settings: settings, participants: participants} = table,
         hand_id
       ) do
    active_participants = filter_active_participants(participants)

    table
    |> Commanded.Aggregate.Multi.new()
    |> Commanded.Aggregate.Multi.execute(fn table ->
      shuffled_deck = Poker.Services.Deck.generate_deck() |> Poker.Services.Deck.shuffle_deck()

      %DeckGenerated{
        hand_id: hand_id,
        table_id: table_id,
        cards: shuffled_deck
      }
    end)
    |> Commanded.Aggregate.Multi.execute(fn table ->
      dealer_button_participant = find_dealer_button_participant(table)

      %DealerButtonMoved{
        table_id: table_id,
        hand_id: hand_id,
        participant_id: dealer_button_participant.id
      }
    end)
    |> Commanded.Aggregate.Multi.execute(fn table ->
      %HandStarted{
        id: hand_id,
        table_id: table_id
      }
    end)
    |> Commanded.Aggregate.Multi.execute(fn table ->
      %RoundStarted{
        id: Ecto.UUID.generate(),
        hand_id: hand_id,
        type: :pre_flop,
        last_bet_amount: settings.big_blind,
        community_cards: []
      }
    end)
    |> Commanded.Aggregate.Multi.reduce(active_participants, fn table, participant ->
      {hole_cards, remaining_deck} = Poker.Services.Deck.pick_cards(table.remaining_deck, 2)

      position = calculate_position(table, participant)

      [
        %ParticipantHandGiven{
          id: Ecto.UUID.generate(),
          table_id: table_id,
          participant_id: participant.id,
          table_hand_id: hand_id,
          hole_cards: hole_cards,
          position: position,
          status: :playing
        },
        %DeckUpdated{
          hand_id: hand_id,
          table_id: table_id,
          cards: remaining_deck
        }
      ]
    end)
    |> Commanded.Aggregate.Multi.execute(fn table ->
      if heads_up?(table) do
        hand = find_participant_hand_by_position(table, :dealer)

        %SmallBlindPosted{
          id: Ecto.UUID.generate(),
          table_id: table.id,
          hand_id: hand_id,
          participant_id: hand.participant_id,
          amount: settings.small_blind
        }
      else
        hand = find_participant_hand_by_position(table, :small_blind)

        %SmallBlindPosted{
          id: Ecto.UUID.generate(),
          table_id: table.id,
          hand_id: hand_id,
          participant_id: hand.participant_id,
          amount: settings.small_blind
        }
      end
    end)
    |> Commanded.Aggregate.Multi.execute(fn table ->
      hand = find_participant_hand_by_position(table, :big_blind)

      %BigBlindPosted{
        id: Ecto.UUID.generate(),
        table_id: table.id,
        hand_id: hand_id,
        participant_id: hand.participant_id,
        amount: settings.big_blind
      }
    end)
    |> Commanded.Aggregate.Multi.execute(fn table ->
      participant_to_act = find_participant_to_act(table)

      %ParticipantToActSelected{
        table_id: table_id,
        hand_id: hand_id,
        participant_id: participant_to_act.id
      }
    end)
    |> Commanded.Aggregate.Multi.execute(fn table ->
      recalculated_pots = recalculate_pots(table)

      %PotsRecalculated{
        table_id: table.id,
        hand_id: hand_id,
        pots: recalculate_pots(table)
      }
    end)
  end

  defp start_round(
         %Table{hand: %{id: hand_id}, remaining_deck: remaining_deck, participants: participants} =
           table,
         command
       ) do
    participant_to_act = find_participant_to_act(table)

    community_cards_count =
      case command.round do
        :flop -> 3
        :turn -> 1
        :river -> 1
      end

    {community_cards, remaining_deck} =
      Poker.Services.Deck.pick_cards(remaining_deck, community_cards_count)

    [
      %RoundStarted{
        id: command.round_id,
        hand_id: command.hand_id,
        type: command.round,
        last_bet_amount: 0,
        community_cards: community_cards
      },
      %DeckUpdated{
        hand_id: command.hand_id,
        table_id: table.id,
        cards: remaining_deck
      },
      %ParticipantToActSelected{
        table_id: table.id,
        hand_id: command.hand_id,
        participant_id: participant_to_act.id
      }
    ]
  end
end
