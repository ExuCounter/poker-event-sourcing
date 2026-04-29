defmodule Poker.Tables.Views.GameStateBuilderTest do
  use Poker.DataCase

  alias Poker.Tables.Views.GameStateBuilder

  describe "build/3 - basic view structure" do
    setup ctx do
      ctx
      |> exec(:create_tournament, settings: %{speed: :hyper_turbo, buy_in: 100, table_type: :two_max})
      |> exec(:fill_tournament)
    end

    test "returns correct view structure", ctx do
      player_id = hd(ctx.table.participants).player_id
      view = GameStateBuilder.build(ctx.table.id, player_id)

      assert Map.has_key?(view, :table_status)
      assert Map.has_key?(view, :total_pot)
      assert Map.has_key?(view, :community_cards)
      assert Map.has_key?(view, :participants)
      assert Map.has_key?(view, :valid_actions)
      assert Map.has_key?(view, :timeout_seconds)
      assert Map.has_key?(view, :current_turn)
      assert Map.has_key?(view, :timeout_info)
    end

    test "returns correct table status", ctx do
      player_id = hd(ctx.table.participants).player_id
      view = GameStateBuilder.build(ctx.table.id, player_id)

      assert view.table_status == :live
    end

    test "returns correct number of participants", ctx do
      player_id = hd(ctx.table.participants).player_id
      view = GameStateBuilder.build(ctx.table.id, player_id)

      assert length(view.participants) == 2
    end
  end

  describe "build/3 - card visibility in live mode" do
    setup ctx do
      ctx
      |> exec(:create_tournament, settings: %{speed: :hyper_turbo, buy_in: 100, table_type: :two_max})
      |> exec(:fill_tournament)
    end

    test "current player sees their own hole cards", ctx do
      [participant1, _participant2] = ctx.table.participants
      view = GameStateBuilder.build(ctx.table.id, participant1.player_id)

      current_player_view =
        Enum.find(view.participants, &(&1.player_id == participant1.player_id))

      assert length(current_player_view.hole_cards) == 2
      assert Enum.all?(current_player_view.hole_cards, &Map.has_key?(&1, :rank))
    end

    test "current player sees opponent cards as hidden", ctx do
      [participant1, participant2] = ctx.table.participants
      view = GameStateBuilder.build(ctx.table.id, participant1.player_id)

      opponent_view =
        Enum.find(view.participants, &(&1.player_id == participant2.player_id))

      assert opponent_view.hole_cards == [nil, nil]
    end
  end

  describe "build/3 - valid actions for player to act" do
    setup ctx do
      ctx
      |> exec(:create_tournament, settings: %{speed: :hyper_turbo, buy_in: 100, table_type: :two_max})
      |> exec(:fill_tournament)
    end

    test "player to act has fold, call, and raise options", ctx do
      acting_participant =
        Enum.find(ctx.table.participants, &(&1.id == ctx.table.round.participant_to_act_id))

      view = GameStateBuilder.build(ctx.table.id, acting_participant.player_id)

      assert view.valid_actions.fold == true
      assert view.valid_actions.check == false
      assert view.valid_actions.call.amount == 10
      assert view.valid_actions.raise.min > 0
      assert view.valid_actions.raise.max > 0
      assert is_list(view.valid_actions.raise.presets)
    end

    test "player not to act has no valid actions", ctx do
      non_acting_participant =
        Enum.find(ctx.table.participants, &(&1.id != ctx.table.round.participant_to_act_id))

      view = GameStateBuilder.build(ctx.table.id, non_acting_participant.player_id)

      assert view.valid_actions.fold == false
      assert view.valid_actions.check == false
      assert view.valid_actions.call == false
      assert view.valid_actions.raise == false
    end

    test "big blind can check when action is on them after call", ctx do
      ctx = ctx |> exec(:call_hand, position: :dealer)

      acting_participant =
        Enum.find(ctx.table.participants, &(&1.id == ctx.table.round.participant_to_act_id))

      view = GameStateBuilder.build(ctx.table.id, acting_participant.player_id)

      assert view.valid_actions.fold == true
      assert view.valid_actions.check == true
      assert view.valid_actions.call == false
      assert view.valid_actions.raise.min > 0
    end
  end

  describe "build/3 - pot and betting" do
    setup ctx do
      ctx
      |> exec(:create_tournament, settings: %{speed: :hyper_turbo, buy_in: 100, table_type: :two_max})
      |> exec(:fill_tournament)
    end

    test "total pot is zero pre-flop before round completes", ctx do
      player_id = hd(ctx.table.participants).player_id
      view = GameStateBuilder.build(ctx.table.id, player_id)

      assert view.total_pot == 0
    end

    test "total pot includes blinds after round completes", ctx do
      ctx =
        ctx
        |> exec(:call_hand, position: :dealer)
        |> exec(:call_hand, position: :big_blind)

      player_id = hd(ctx.table.participants).player_id
      view = GameStateBuilder.build(ctx.table.id, player_id)

      assert view.total_pot == 40
    end

    test "participant bet_this_round is tracked", ctx do
      player_id = hd(ctx.table.participants).player_id
      view = GameStateBuilder.build(ctx.table.id, player_id)

      bets = Enum.map(view.participants, & &1.bet_this_round)
      assert Enum.member?(bets, 10)
      assert Enum.member?(bets, 20)
    end
  end

  describe "build/3 - current turn tracking" do
    setup ctx do
      ctx
      |> exec(:create_tournament, settings: %{speed: :hyper_turbo, buy_in: 100, table_type: :two_max})
      |> exec(:fill_tournament)
    end

    test "current_turn contains participant_to_act_id", ctx do
      player_id = hd(ctx.table.participants).player_id
      view = GameStateBuilder.build(ctx.table.id, player_id)

      assert view.current_turn.participant_id == ctx.table.round.participant_to_act_id
    end
  end

  describe "build/3 - timeout info" do
    setup ctx do
      ctx
      |> exec(:create_tournament, settings: %{speed: :hyper_turbo, buy_in: 100, table_type: :two_max})
      |> exec(:fill_tournament)
    end

    test "timeout_seconds is from settings", ctx do
      player_id = hd(ctx.table.participants).player_id
      view = GameStateBuilder.build(ctx.table.id, player_id)

      assert view.timeout_seconds == 30
    end

    test "timeout_info has started_at and timeout_seconds", ctx do
      player_id = hd(ctx.table.participants).player_id
      view = GameStateBuilder.build(ctx.table.id, player_id)

      assert Map.has_key?(view.timeout_info, :started_at)
      assert Map.has_key?(view.timeout_info, :timeout_seconds)
    end
  end

  describe "build/3 - community cards" do
    setup ctx do
      ctx
      |> exec(:create_tournament, settings: %{speed: :hyper_turbo, buy_in: 100, table_type: :two_max})
      |> exec(:fill_tournament)
    end

    test "no community cards pre-flop", ctx do
      player_id = hd(ctx.table.participants).player_id
      view = GameStateBuilder.build(ctx.table.id, player_id)

      assert view.community_cards == []
    end

    test "3 community cards on flop", ctx do
      ctx =
        ctx
        |> exec(:call_hand, position: :dealer)
        |> exec(:call_hand, position: :big_blind)

      player_id = hd(ctx.table.participants).player_id
      view = GameStateBuilder.build(ctx.table.id, player_id)

      assert length(view.community_cards) == 3
    end
  end

  describe "build/3 - folded player" do
    setup ctx do
      ctx
      |> exec(:create_tournament, settings: %{speed: :hyper_turbo, buy_in: 100, table_type: :three_max})
      |> exec(:fill_tournament)
    end

    test "folded player sees empty hole cards", ctx do
      folded_participant_id = ctx.table.round.participant_to_act_id
      folded_participant =
        Enum.find(ctx.table.participants, &(&1.id == folded_participant_id))

      _ctx = ctx |> exec(:fold_hand, position: :dealer)

      view = GameStateBuilder.build(ctx.table.id, folded_participant.player_id)

      current_player_view =
        Enum.find(view.participants, &(&1.player_id == folded_participant.player_id))

      assert current_player_view.hole_cards == []
      assert current_player_view.hand_status == :folded
    end
  end

  describe "build/3 - participant info" do
    setup ctx do
      ctx
      |> exec(:create_tournament, settings: %{speed: :hyper_turbo, buy_in: 100, table_type: :two_max})
      |> exec(:fill_tournament)
    end

    test "participant has all required fields", ctx do
      player_id = hd(ctx.table.participants).player_id
      view = GameStateBuilder.build(ctx.table.id, player_id)

      participant = hd(view.participants)

      assert Map.has_key?(participant, :id)
      assert Map.has_key?(participant, :player_id)
      assert Map.has_key?(participant, :chips)
      assert Map.has_key?(participant, :position)
      assert Map.has_key?(participant, :status)
      assert Map.has_key?(participant, :bet_this_round)
      assert Map.has_key?(participant, :hand_status)
      assert Map.has_key?(participant, :hole_cards)
      assert Map.has_key?(participant, :is_sitting_out)
    end

    test "participant chips are tracked correctly", ctx do
      player_id = hd(ctx.table.participants).player_id
      view = GameStateBuilder.build(ctx.table.id, player_id)

      chips = Enum.map(view.participants, & &1.chips)
      assert Enum.member?(chips, 490)
      assert Enum.member?(chips, 480)
    end
  end

  # Paused table test moved to cash game tests — tournaments don't pause on sit-out

  describe "build/3 - calculate_actions option" do
    setup ctx do
      ctx
      |> exec(:create_tournament, settings: %{speed: :hyper_turbo, buy_in: 100, table_type: :two_max})
      |> exec(:fill_tournament)
    end

    test "with calculate_actions: false returns default actions", ctx do
      acting_participant =
        Enum.find(ctx.table.participants, &(&1.id == ctx.table.round.participant_to_act_id))

      view = GameStateBuilder.build(ctx.table.id, acting_participant.player_id, calculate_actions: false)

      assert view.valid_actions.fold == false
      assert view.valid_actions.check == false
      assert view.valid_actions.call == false
      assert view.valid_actions.raise == false
    end
  end

  describe "replay_events/2 - basic replay" do
    setup ctx do
      ctx
      |> exec(:create_tournament, settings: %{speed: :hyper_turbo, buy_in: 100, table_type: :two_max})
      |> exec(:fill_tournament)
    end

    test "replays events from beginning and matches Commanded aggregate state", ctx do
      %{aggregate: replayed_aggregate} = GameStateBuilder.replay_events(ctx.table.id)
      commanded_aggregate = get_commanded_aggregate(ctx.table.id)

      assert replayed_aggregate == commanded_aggregate
    end

  end

  describe "replay_events/2 - replay with hand history checkpoint" do
    setup ctx do
      ctx
      |> exec(:create_tournament, settings: %{speed: :hyper_turbo, buy_in: 100, table_type: :two_max})
      |> exec(:fill_tournament)
    end

    test "replayed aggregate matches Commanded aggregate state after hand started", ctx do
      %{aggregate: replayed_aggregate} = GameStateBuilder.replay_events(ctx.table.id)
      commanded_aggregate = get_commanded_aggregate(ctx.table.id)

      assert replayed_aggregate == commanded_aggregate
    end

    test "replayed aggregate matches after call action", ctx do
      ctx = ctx |> exec(:call_hand, position: :dealer)

      %{aggregate: replayed_aggregate} = GameStateBuilder.replay_events(ctx.table.id)
      commanded_aggregate = get_commanded_aggregate(ctx.table.id)

      assert replayed_aggregate == commanded_aggregate
    end

    test "replayed aggregate matches after raise action", ctx do
      ctx = ctx |> exec(:raise_hand, position: :dealer, amount: 60)

      %{aggregate: replayed_aggregate} = GameStateBuilder.replay_events(ctx.table.id)
      commanded_aggregate = get_commanded_aggregate(ctx.table.id)

      assert replayed_aggregate == commanded_aggregate
    end

    test "replayed aggregate matches after fold action", ctx do
      ctx = ctx |> exec(:fold_hand, position: :dealer)

      %{aggregate: replayed_aggregate} = GameStateBuilder.replay_events(ctx.table.id)
      commanded_aggregate = get_commanded_aggregate(ctx.table.id)

      assert replayed_aggregate == commanded_aggregate
    end

    test "replayed aggregate matches after completing pre-flop round", ctx do
      ctx =
        ctx
        |> exec(:call_hand, position: :dealer)
        |> exec(:call_hand, position: :big_blind)

      %{aggregate: replayed_aggregate} = GameStateBuilder.replay_events(ctx.table.id)
      commanded_aggregate = get_commanded_aggregate(ctx.table.id)

      assert replayed_aggregate == commanded_aggregate
    end
  end

  describe "replay_events/2 - multi-player game consistency" do
    setup ctx do
      ctx
      |> exec(:create_tournament, settings: %{speed: :hyper_turbo, buy_in: 100, table_type: :three_max})
      |> exec(:fill_tournament)
    end

    test "replayed aggregate matches throughout betting sequence", ctx do
      assert_replay_matches_commanded(ctx.table.id)

      ctx = ctx |> exec(:call_hand, position: :dealer)
      assert_replay_matches_commanded(ctx.table.id)

      ctx = ctx |> exec(:call_hand, position: :small_blind)
      assert_replay_matches_commanded(ctx.table.id)

      ctx = ctx |> exec(:check_hand, position: :big_blind)
      assert_replay_matches_commanded(ctx.table.id)
    end

    test "replayed aggregate matches after all-in", ctx do
      ctx = ctx |> exec(:all_in_hand, position: :dealer)

      %{aggregate: replayed_aggregate} = GameStateBuilder.replay_events(ctx.table.id)
      commanded_aggregate = get_commanded_aggregate(ctx.table.id)

      assert replayed_aggregate == commanded_aggregate
    end
  end

  defp get_commanded_aggregate(table_id) do
    Poker.TestSupport.ProcessManagerAwaiter.wait_to_settle()

    Commanded.Aggregates.Aggregate.aggregate_state(
      Poker.App,
      Poker.Tables.Aggregates.Table,
      "table-" <> table_id
    )
  end

  defp assert_replay_matches_commanded(table_id) do
    %{aggregate: replayed_aggregate} = GameStateBuilder.replay_events(table_id)
    commanded_aggregate = get_commanded_aggregate(table_id)

    assert replayed_aggregate == commanded_aggregate
  end
end
