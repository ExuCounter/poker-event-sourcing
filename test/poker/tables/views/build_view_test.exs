defmodule Poker.Tables.Views.BuildViewTest do
  use Poker.DataCase

  alias Poker.Tables.Views.GameStateBuilder
  alias Poker.Tables.Aggregates.Table

  # ---------------------------------------------------------------------------
  # Test helpers — build aggregate structs directly
  # ---------------------------------------------------------------------------

  defp player_id, do: Ecto.UUID.generate()
  defp participant_id, do: Ecto.UUID.generate()

  defp base_settings do
    %{
      small_blind: 10,
      big_blind: 20,
      starting_stack: 1000,
      timeout_seconds: 30,
      table_type: :six_max
    }
  end

  defp make_participant(overrides \\ []) do
    Map.merge(
      %{
        id: participant_id(),
        player_id: player_id(),
        nickname: "player",
        chips: 1000,
        seat_number: 1,
        status: :active,
        is_sitting_out: false
      },
      Map.new(overrides)
    )
  end

  defp make_participant_hand(participant_id, overrides \\ []) do
    Map.merge(
      %{
        id: Ecto.UUID.generate(),
        participant_id: participant_id,
        hole_cards: [%{rank: :A, suit: :spades}, %{rank: :K, suit: :hearts}],
        position: :dealer,
        status: :active,
        bet_this_round: 0,
        total_bet_this_hand: 0,
        folded_at: nil
      },
      Map.new(overrides)
    )
  end

  defp make_table(overrides \\ %{}) do
    defaults = %{
      id: Ecto.UUID.generate(),
      creator_id: Ecto.UUID.generate(),
      status: :live,
      game_mode: :tournament,
      source_id: Ecto.UUID.generate(),
      settings: base_settings(),
      participants: [],
      hand: %{id: Ecto.UUID.generate()},
      round: nil,
      community_cards: [],
      pots: [],
      participant_hands: [],
      remaining_deck: nil,
      dealer_button_id: nil,
      payouts: []
    }

    struct(Table, Map.merge(defaults, Map.new(overrides)))
  end

  defp make_round(participant_to_act_id, overrides \\ []) do
    Map.merge(
      %{
        id: Ecto.UUID.generate(),
        type: :pre_flop,
        started_at: DateTime.utc_now(),
        timeout_seconds: 30,
        participant_to_act_id: participant_to_act_id,
        acted_participant_ids: []
      },
      Map.new(overrides)
    )
  end

  defp view(aggregate, player_id, opts \\ []) do
    GameStateBuilder.build_view(aggregate, player_id, opts)
  end

  # ---------------------------------------------------------------------------
  # Table metadata
  # ---------------------------------------------------------------------------

  describe "build_view - table metadata" do
    test "returns table_status from aggregate" do
      table = make_table(status: :waiting)
      v = view(table, player_id())

      assert v.table_status == :waiting
    end

    test "returns table_type from settings" do
      table = make_table(settings: %{base_settings() | table_type: :two_max})
      v = view(table, player_id())

      assert v.table_type == :two_max
    end

    test "returns nil table_type when no settings" do
      table = make_table(settings: nil)
      v = view(table, player_id())

      assert v.table_type == nil
    end

    test "returns game_mode from aggregate" do
      table = make_table(game_mode: :cash_game)
      v = view(table, player_id())

      assert v.game_mode == :cash_game
    end

    test "returns source_id from aggregate" do
      source_id = Ecto.UUID.generate()
      table = make_table(source_id: source_id)
      v = view(table, player_id())

      assert v.source_id == source_id
    end

    test "returns timeout_seconds from settings" do
      table = make_table(settings: %{base_settings() | timeout_seconds: 90})
      v = view(table, player_id())

      assert v.timeout_seconds == 90
    end

    test "returns nil timeout_seconds when no settings" do
      table = make_table(settings: nil)
      v = view(table, player_id())

      assert v.timeout_seconds == nil
    end
  end

  # ---------------------------------------------------------------------------
  # Total pot
  # ---------------------------------------------------------------------------

  describe "build_view - total_pot" do
    test "returns sum of all pots when hand active" do
      table = make_table(pots: [%{amount: 100}, %{amount: 50}])
      v = view(table, player_id())

      assert v.total_pot == 150
    end

    test "returns 0 when no pots" do
      table = make_table(pots: [])
      v = view(table, player_id())

      assert v.total_pot == 0
    end

    test "returns 0 when hand is finished" do
      table = make_table(hand: %{id: Ecto.UUID.generate(), status: :finished}, pots: [%{amount: 200}])
      v = view(table, player_id())

      assert v.total_pot == 0
    end

    test "returns 0 when no hand" do
      table = make_table(hand: nil, pots: [%{amount: 200}])
      v = view(table, player_id())

      assert v.total_pot == 0
    end
  end

  # ---------------------------------------------------------------------------
  # Community cards
  # ---------------------------------------------------------------------------

  describe "build_view - community_cards" do
    test "returns community cards when hand active" do
      cards = [%{rank: :A, suit: :spades}, %{rank: :K, suit: :hearts}, %{rank: :Q, suit: :diamonds}]
      table = make_table(community_cards: cards)
      v = view(table, player_id())

      assert v.community_cards == cards
    end

    test "returns [] when no hand" do
      table = make_table(hand: nil, community_cards: [%{rank: :A, suit: :spades}])
      v = view(table, player_id())

      assert v.community_cards == []
    end

    test "returns [] when hand finished" do
      table = make_table(
        hand: %{id: Ecto.UUID.generate(), status: :finished},
        community_cards: [%{rank: :A, suit: :spades}]
      )
      v = view(table, player_id())

      assert v.community_cards == []
    end

    test "returns [] when table paused" do
      table = make_table(status: :paused, community_cards: [%{rank: :A, suit: :spades}])
      v = view(table, player_id())

      assert v.community_cards == []
    end
  end

  # ---------------------------------------------------------------------------
  # Current turn
  # ---------------------------------------------------------------------------

  describe "build_view - current_turn" do
    test "returns participant_id when someone is acting" do
      p = make_participant()
      table = make_table(
        participants: [p],
        round: make_round(p.id)
      )
      v = view(table, player_id())

      assert v.current_turn == %{participant_id: p.id}
    end

    test "returns nil when no hand" do
      table = make_table(hand: nil)
      v = view(table, player_id())

      assert v.current_turn == nil
    end

    test "returns nil when hand finished" do
      table = make_table(hand: %{id: Ecto.UUID.generate(), status: :finished})
      v = view(table, player_id())

      assert v.current_turn == nil
    end

    test "returns nil when no round" do
      table = make_table(round: nil)
      v = view(table, player_id())

      assert v.current_turn == nil
    end
  end

  # ---------------------------------------------------------------------------
  # Timeout info
  # ---------------------------------------------------------------------------

  describe "build_view - timeout_info" do
    test "returns started_at and timeout_seconds from round" do
      now = DateTime.utc_now()
      p = make_participant()
      table = make_table(
        participants: [p],
        round: make_round(p.id, started_at: now, timeout_seconds: 60)
      )
      v = view(table, player_id())

      assert v.timeout_info == %{started_at: now, timeout_seconds: 60}
    end

    test "returns nil when no hand" do
      table = make_table(hand: nil)
      v = view(table, player_id())

      assert v.timeout_info == nil
    end

    test "returns nil when hand finished" do
      table = make_table(hand: %{id: Ecto.UUID.generate(), status: :finished})
      v = view(table, player_id())

      assert v.timeout_info == nil
    end

    test "returns nil when round has no started_at" do
      p = make_participant()
      table = make_table(
        participants: [p],
        round: make_round(p.id, started_at: nil, timeout_seconds: nil)
      )
      v = view(table, player_id())

      assert v.timeout_info == nil
    end
  end

  # ---------------------------------------------------------------------------
  # Hole cards visibility — live mode
  # ---------------------------------------------------------------------------

  describe "build_view - hole cards (live mode)" do
    test "current player sees own hole cards" do
      pid = player_id()
      p = make_participant(player_id: pid)
      ph = make_participant_hand(p.id, hole_cards: [%{rank: :A, suit: :spades}, %{rank: :K, suit: :hearts}])
      table = make_table(participants: [p], participant_hands: [ph])

      v = view(table, pid)

      current = Enum.find(v.participants, &(&1.player_id == pid))
      assert length(current.hole_cards) == 2
      assert hd(current.hole_cards).rank == :A
    end

    test "current player sees [] when folded" do
      pid = player_id()
      p = make_participant(player_id: pid)
      ph = make_participant_hand(p.id, status: :folded)
      table = make_table(participants: [p], participant_hands: [ph])

      v = view(table, pid)

      current = Enum.find(v.participants, &(&1.player_id == pid))
      assert current.hole_cards == []
    end

    test "opponent cards shown as [nil, nil] when they have cards" do
      my_pid = player_id()
      opp_pid = player_id()
      me = make_participant(player_id: my_pid, seat_number: 1)
      opp = make_participant(player_id: opp_pid, seat_number: 2)
      my_hand = make_participant_hand(me.id)
      opp_hand = make_participant_hand(opp.id)
      table = make_table(participants: [me, opp], participant_hands: [my_hand, opp_hand])

      v = view(table, my_pid)

      opponent = Enum.find(v.participants, &(&1.player_id == opp_pid))
      assert opponent.hole_cards == [nil, nil]
    end

    test "opponent cards shown as [] when folded" do
      my_pid = player_id()
      opp_pid = player_id()
      me = make_participant(player_id: my_pid, seat_number: 1)
      opp = make_participant(player_id: opp_pid, seat_number: 2)
      my_hand = make_participant_hand(me.id)
      opp_hand = make_participant_hand(opp.id, status: :folded)
      table = make_table(participants: [me, opp], participant_hands: [my_hand, opp_hand])

      v = view(table, my_pid)

      opponent = Enum.find(v.participants, &(&1.player_id == opp_pid))
      assert opponent.hole_cards == []
    end

    test "opponent cards shown as [] when they have no cards" do
      my_pid = player_id()
      opp_pid = player_id()
      me = make_participant(player_id: my_pid, seat_number: 1)
      opp = make_participant(player_id: opp_pid, seat_number: 2)
      my_hand = make_participant_hand(me.id)
      table = make_table(participants: [me, opp], participant_hands: [my_hand])

      v = view(table, my_pid)

      opponent = Enum.find(v.participants, &(&1.player_id == opp_pid))
      assert opponent.hole_cards == []
    end

    test "all cards [] when hand finished" do
      my_pid = player_id()
      me = make_participant(player_id: my_pid)
      my_hand = make_participant_hand(me.id)
      table = make_table(
        participants: [me],
        participant_hands: [my_hand],
        hand: %{id: Ecto.UUID.generate(), status: :finished}
      )

      v = view(table, my_pid)

      current = Enum.find(v.participants, &(&1.player_id == my_pid))
      assert current.hole_cards == []
    end

    test "all cards [] when table paused" do
      my_pid = player_id()
      me = make_participant(player_id: my_pid)
      my_hand = make_participant_hand(me.id)
      table = make_table(status: :paused, participants: [me], participant_hands: [my_hand])

      v = view(table, my_pid)

      current = Enum.find(v.participants, &(&1.player_id == my_pid))
      assert current.hole_cards == []
    end
  end

  # ---------------------------------------------------------------------------
  # Hole cards visibility — replay mode
  # ---------------------------------------------------------------------------

  describe "build_view - hole cards (replay mode)" do
    test "current player sees own hole cards" do
      pid = player_id()
      p = make_participant(player_id: pid)
      ph = make_participant_hand(p.id)
      table = make_table(participants: [p], participant_hands: [ph])

      v = view(table, pid, visibility_mode: :replay)

      current = Enum.find(v.participants, &(&1.player_id == pid))
      assert length(current.hole_cards) == 2
    end

    test "opponent revealed showdown cards are visible" do
      my_pid = player_id()
      opp_pid = player_id()
      me = make_participant(player_id: my_pid, seat_number: 1)
      opp = make_participant(player_id: opp_pid, seat_number: 2)
      my_hand = make_participant_hand(me.id)
      opp_hand = make_participant_hand(opp.id)

      revealed = [%{rank: :Q, suit: :clubs}, %{rank: :J, suit: :diamonds}]

      table =
        make_table(participants: [me, opp], participant_hands: [my_hand, opp_hand])
        |> Map.put(:revealed_cards, %{opp.id => revealed})

      v = view(table, my_pid, visibility_mode: :replay)

      opponent = Enum.find(v.participants, &(&1.player_id == opp_pid))
      assert opponent.hole_cards == revealed
    end

    test "opponent without revealed cards shown as [nil, nil]" do
      my_pid = player_id()
      opp_pid = player_id()
      me = make_participant(player_id: my_pid, seat_number: 1)
      opp = make_participant(player_id: opp_pid, seat_number: 2)
      my_hand = make_participant_hand(me.id)
      opp_hand = make_participant_hand(opp.id)
      table = make_table(participants: [me, opp], participant_hands: [my_hand, opp_hand])

      v = view(table, my_pid, visibility_mode: :replay)

      opponent = Enum.find(v.participants, &(&1.player_id == opp_pid))
      assert opponent.hole_cards == [nil, nil]
    end
  end

  # ---------------------------------------------------------------------------
  # Participant fields
  # ---------------------------------------------------------------------------

  describe "build_view - participant fields" do
    test "includes all expected fields" do
      pid = player_id()
      p = make_participant(player_id: pid, nickname: "hero", chips: 500, seat_number: 3)
      ph = make_participant_hand(p.id, position: :big_blind, bet_this_round: 20)
      table = make_table(participants: [p], participant_hands: [ph])

      v = view(table, pid)
      participant = hd(v.participants)

      assert participant.id == p.id
      assert participant.player_id == pid
      assert participant.nickname == "hero"
      assert participant.chips == 500
      assert participant.seat_number == 3
      assert participant.status == :active
      assert participant.is_sitting_out == false
      assert participant.position == :big_blind
      assert participant.bet_this_round == 20
      assert participant.hand_status == :active
    end

    test "position is nil when hand finished" do
      p = make_participant()
      ph = make_participant_hand(p.id, position: :dealer)
      table = make_table(
        participants: [p],
        participant_hands: [ph],
        hand: %{id: Ecto.UUID.generate(), status: :finished}
      )

      v = view(table, player_id())
      participant = hd(v.participants)

      assert participant.position == nil
    end

    test "bet_this_round is 0 when hand finished" do
      p = make_participant()
      ph = make_participant_hand(p.id, bet_this_round: 50)
      table = make_table(
        participants: [p],
        participant_hands: [ph],
        hand: %{id: Ecto.UUID.generate(), status: :finished}
      )

      v = view(table, player_id())
      participant = hd(v.participants)

      assert participant.bet_this_round == 0
    end

    test "hand_status is nil when hand finished" do
      p = make_participant()
      ph = make_participant_hand(p.id, status: :active)
      table = make_table(
        participants: [p],
        participant_hands: [ph],
        hand: %{id: Ecto.UUID.generate(), status: :finished}
      )

      v = view(table, player_id())
      participant = hd(v.participants)

      assert participant.hand_status == nil
    end

    test "equity is nil when no revealed cards" do
      p = make_participant()
      ph = make_participant_hand(p.id)
      table = make_table(participants: [p], participant_hands: [ph])

      v = view(table, player_id())
      participant = hd(v.participants)

      assert participant.equity == nil
    end
  end

  # ---------------------------------------------------------------------------
  # Valid actions
  # ---------------------------------------------------------------------------

  describe "build_view - valid_actions" do
    test "player to act gets fold, call, raise" do
      pid = player_id()
      p = make_participant(player_id: pid, chips: 980)
      ph = make_participant_hand(p.id, bet_this_round: 0)
      opp = make_participant(seat_number: 2, chips: 980)
      opp_hand = make_participant_hand(opp.id, bet_this_round: 20, position: :big_blind)

      table = make_table(
        participants: [p, opp],
        participant_hands: [ph, opp_hand],
        round: make_round(p.id)
      )

      v = view(table, pid)

      assert v.valid_actions.fold == true
      assert v.valid_actions.call.amount == 20
      assert v.valid_actions.raise.min > 0
      assert v.valid_actions.raise.max > 0
    end

    test "player to act can check when no bet to call" do
      pid = player_id()
      p = make_participant(player_id: pid, chips: 980)
      ph = make_participant_hand(p.id, bet_this_round: 20)
      opp = make_participant(seat_number: 2, chips: 980)
      opp_hand = make_participant_hand(opp.id, bet_this_round: 20, position: :dealer)

      table = make_table(
        participants: [p, opp],
        participant_hands: [ph, opp_hand],
        round: make_round(p.id)
      )

      v = view(table, pid)

      assert v.valid_actions.fold == true
      assert v.valid_actions.check == true
      assert v.valid_actions.call == false
    end

    test "player not to act gets all false" do
      pid = player_id()
      p = make_participant(player_id: pid)
      other = make_participant(seat_number: 2)

      table = make_table(
        participants: [p, other],
        participant_hands: [make_participant_hand(p.id), make_participant_hand(other.id)],
        round: make_round(other.id)
      )

      v = view(table, pid)

      assert v.valid_actions == %{fold: false, check: false, call: false, raise: false}
    end

    test "all false when hand finished" do
      pid = player_id()
      p = make_participant(player_id: pid)

      table = make_table(
        participants: [p],
        participant_hands: [make_participant_hand(p.id)],
        hand: %{id: Ecto.UUID.generate(), status: :finished},
        round: make_round(p.id)
      )

      v = view(table, pid)

      assert v.valid_actions == %{fold: false, check: false, call: false, raise: false}
    end

    test "all false when table paused" do
      pid = player_id()
      p = make_participant(player_id: pid)

      table = make_table(
        status: :paused,
        participants: [p],
        participant_hands: [make_participant_hand(p.id)],
        round: make_round(p.id)
      )

      v = view(table, pid)

      assert v.valid_actions == %{fold: false, check: false, call: false, raise: false}
    end

    test "all false when calculate_actions: false" do
      pid = player_id()
      p = make_participant(player_id: pid)

      table = make_table(
        participants: [p],
        participant_hands: [make_participant_hand(p.id)],
        round: make_round(p.id)
      )

      v = view(table, pid, calculate_actions: false)

      assert v.valid_actions == %{fold: false, check: false, call: false, raise: false}
    end

    test "all false when player not found" do
      table = make_table(participants: [make_participant()])
      v = view(table, player_id())

      assert v.valid_actions == %{fold: false, check: false, call: false, raise: false}
    end

    test "raise is false when player can only call" do
      pid = player_id()
      p = make_participant(player_id: pid, chips: 15)
      ph = make_participant_hand(p.id, bet_this_round: 0)
      opp = make_participant(seat_number: 2, chips: 980)
      opp_hand = make_participant_hand(opp.id, bet_this_round: 20, position: :big_blind)

      table = make_table(
        participants: [p, opp],
        participant_hands: [ph, opp_hand],
        round: make_round(p.id)
      )

      v = view(table, pid)

      assert v.valid_actions.fold == true
      assert v.valid_actions.call.amount == 15
      assert v.valid_actions.raise == false
    end

    test "all-in raise when chips exceed call but below min raise" do
      pid = player_id()
      p = make_participant(player_id: pid, chips: 30)
      ph = make_participant_hand(p.id, bet_this_round: 0)
      opp = make_participant(seat_number: 2, chips: 980)
      opp_hand = make_participant_hand(opp.id, bet_this_round: 20, position: :big_blind)

      table = make_table(
        participants: [p, opp],
        participant_hands: [ph, opp_hand],
        round: make_round(p.id)
      )

      v = view(table, pid)

      assert v.valid_actions.fold == true
      assert v.valid_actions.call.amount == 20
      assert v.valid_actions.raise.min == v.valid_actions.raise.max
      assert v.valid_actions.raise.presets == [%{label: "All In", value: 30}]
    end
  end

  # ---------------------------------------------------------------------------
  # Player actions — tournament
  # ---------------------------------------------------------------------------

  describe "build_view - player_actions (tournament)" do
    test "participant can sit out, cannot leave" do
      pid = player_id()
      p = make_participant(player_id: pid, is_sitting_out: false)
      table = make_table(game_mode: :tournament, participants: [p])

      v = view(table, pid)

      assert v.player_actions.is_participant == true
      assert v.player_actions.can_sit_out == true
      assert v.player_actions.can_leave == false
      assert v.player_actions.can_join_seat == false
    end

    test "sitting-out participant can sit in" do
      pid = player_id()
      p = make_participant(player_id: pid, is_sitting_out: true, chips: 500)
      table = make_table(game_mode: :tournament, participants: [p])

      v = view(table, pid)

      assert v.player_actions.can_sit_in == true
      assert v.player_actions.can_sit_out == false
    end

    test "sitting-out participant with 0 chips cannot sit in" do
      pid = player_id()
      p = make_participant(player_id: pid, is_sitting_out: true, chips: 0)
      table = make_table(game_mode: :tournament, participants: [p])

      v = view(table, pid)

      assert v.player_actions.can_sit_in == false
    end

    test "non-participant in tournament" do
      table = make_table(game_mode: :tournament, participants: [make_participant()])
      v = view(table, player_id())

      assert v.player_actions.is_participant == false
      assert v.player_actions.can_join_seat == false
    end

    test "can_buy_in always false in tournament" do
      pid = player_id()
      p = make_participant(player_id: pid)
      table = make_table(game_mode: :tournament, participants: [p])

      v = view(table, pid)

      assert v.player_actions.can_buy_in == false
    end
  end

  # ---------------------------------------------------------------------------
  # Player actions — cash game
  # ---------------------------------------------------------------------------

  describe "build_view - player_actions (cash game)" do
    test "participant can leave and join seat" do
      pid = player_id()
      p = make_participant(player_id: pid)
      table = make_table(game_mode: :cash_game, participants: [p])

      v = view(table, pid)

      assert v.player_actions.can_leave == true
      assert v.player_actions.can_join_seat == true
    end

    test "non-participant can join seat in cash game" do
      table = make_table(game_mode: :cash_game, participants: [make_participant()])
      v = view(table, player_id())

      assert v.player_actions.can_join_seat == true
      assert v.player_actions.is_participant == false
    end

    test "can_buy_in with valid game_context and room under max_buyin" do
      pid = player_id()
      p = make_participant(player_id: pid, chips: 500)
      table = make_table(game_mode: :cash_game, participants: [p])
      ctx = %{type: :cash_game, min_buyin: 200, max_buyin: 2000}

      v = view(table, pid, game_context: ctx)

      assert v.player_actions.can_buy_in == %{min: 200, max: 1500}
    end

    test "can_buy_in false when no game_context" do
      pid = player_id()
      p = make_participant(player_id: pid, chips: 500)
      table = make_table(game_mode: :cash_game, participants: [p])

      v = view(table, pid)

      assert v.player_actions.can_buy_in == false
    end

    test "can_buy_in false when already at max_buyin" do
      pid = player_id()
      p = make_participant(player_id: pid, chips: 2000)
      table = make_table(game_mode: :cash_game, participants: [p])
      ctx = %{type: :cash_game, min_buyin: 200, max_buyin: 2000}

      v = view(table, pid, game_context: ctx)

      assert v.player_actions.can_buy_in == false
    end
  end

  # ---------------------------------------------------------------------------
  # My hand rank
  # ---------------------------------------------------------------------------

  describe "build_view - my_hand_rank" do
    test "returns hand rank when player has hole cards and community cards" do
      pid = player_id()
      p = make_participant(player_id: pid)
      ph = make_participant_hand(p.id, hole_cards: [%{rank: :A, suit: :spades}, %{rank: :A, suit: :hearts}])
      community = [%{rank: :K, suit: :clubs}, %{rank: :Q, suit: :diamonds}, %{rank: :J, suit: :spades}]
      table = make_table(participants: [p], participant_hands: [ph], community_cards: community)

      v = view(table, pid)

      assert v.my_hand_rank != nil
      assert v.my_hand_rank.display_name != nil
    end

    test "returns hand rank with only hole cards (pair)" do
      pid = player_id()
      p = make_participant(player_id: pid)
      ph = make_participant_hand(p.id, hole_cards: [%{rank: :A, suit: :spades}, %{rank: :A, suit: :hearts}])
      table = make_table(participants: [p], participant_hands: [ph], community_cards: [])

      v = view(table, pid)

      assert v.my_hand_rank != nil
    end

    test "returns nil when player has no hole cards" do
      pid = player_id()
      p = make_participant(player_id: pid)
      table = make_table(participants: [p], participant_hands: [])

      v = view(table, pid)

      assert v.my_hand_rank == nil
    end

    test "returns nil when hand finished" do
      pid = player_id()
      p = make_participant(player_id: pid)
      ph = make_participant_hand(p.id)
      table = make_table(
        participants: [p],
        participant_hands: [ph],
        hand: %{id: Ecto.UUID.generate(), status: :finished}
      )

      v = view(table, pid)

      assert v.my_hand_rank == nil
    end

    test "returns nil when table paused" do
      pid = player_id()
      p = make_participant(player_id: pid)
      ph = make_participant_hand(p.id)
      table = make_table(status: :paused, participants: [p], participant_hands: [ph])

      v = view(table, pid)

      assert v.my_hand_rank == nil
    end

    test "returns nil when player not found" do
      table = make_table(participants: [make_participant()])
      v = view(table, player_id())

      assert v.my_hand_rank == nil
    end
  end
end
