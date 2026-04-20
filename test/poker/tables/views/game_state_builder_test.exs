defmodule Poker.Tables.Views.GameStateBuilderTest do
  use Poker.DataCase

  alias Poker.Tables.Views.GameStateBuilder

  describe "build/3 - basic view structure" do
    setup ctx do
      ctx
      |> exec(:create_table,
        type: :six_max,
        settings: %{
          small_blind: 10,
          big_blind: 20,
          starting_stack: 1000,
          timeout_seconds: 60
        }
      )
      |> exec(:add_participants, generate_players: 2)
      |> exec(:start_table)
    end

    test "returns correct view structure", ctx do
      player_id = hd(ctx.table.participants).player_id
      view = GameStateBuilder.build(ctx.table.id, player_id)

      assert Map.has_key?(view, :table_status)
      assert Map.has_key?(view, :hand_id)
      assert Map.has_key?(view, :total_pot)
      assert Map.has_key?(view, :community_cards)
      assert Map.has_key?(view, :participants)
      assert Map.has_key?(view, :valid_actions)
      assert Map.has_key?(view, :latest_version)
      assert Map.has_key?(view, :hand_status)
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
      |> exec(:create_table,
        type: :six_max,
        settings: %{
          small_blind: 10,
          big_blind: 20,
          starting_stack: 1000,
          timeout_seconds: 60
        }
      )
      |> exec(:add_participants, generate_players: 2)
      |> exec(:start_table)
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
      |> exec(:create_table,
        type: :six_max,
        settings: %{
          small_blind: 10,
          big_blind: 20,
          starting_stack: 1000,
          timeout_seconds: 60
        }
      )
      |> exec(:add_participants, generate_players: 2)
      |> exec(:start_table)
    end

    test "player to act has fold, call, and raise options", ctx do
      acting_participant =
        Enum.find(ctx.table.participants, &(&1.id == ctx.table.round.participant_to_act_id))

      view = GameStateBuilder.build(ctx.table.id, acting_participant.player_id)

      # In heads-up pre-flop, dealer (SB) acts first
      assert view.valid_actions.fold == true
      assert view.valid_actions.check == false  # Can't check when facing big blind
      assert view.valid_actions.call.amount == 10  # Call amount to match BB (20 - 10 SB already posted)
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
      # Dealer calls
      ctx = ctx |> exec(:call_hand)

      # Now BB can check
      acting_participant =
        Enum.find(ctx.table.participants, &(&1.id == ctx.table.round.participant_to_act_id))

      view = GameStateBuilder.build(ctx.table.id, acting_participant.player_id)

      assert view.valid_actions.fold == true
      assert view.valid_actions.check == true
      assert view.valid_actions.call == false  # No bet to call
      assert view.valid_actions.raise.min > 0
    end
  end

  describe "build/3 - pot and betting" do
    setup ctx do
      ctx
      |> exec(:create_table,
        type: :six_max,
        settings: %{
          small_blind: 10,
          big_blind: 20,
          starting_stack: 1000,
          timeout_seconds: 60
        }
      )
      |> exec(:add_participants, generate_players: 2)
      |> exec(:start_table)
    end

    test "total pot is zero pre-flop before round completes", ctx do
      player_id = hd(ctx.table.participants).player_id
      view = GameStateBuilder.build(ctx.table.id, player_id)

      # Pre-flop: blinds are bet_this_round, not in pots yet
      assert view.total_pot == 0
    end

    test "total pot includes blinds after round completes", ctx do
      # Complete pre-flop round to move bets into pot
      ctx =
        ctx
        |> exec(:call_hand)
        |> exec(:check_hand)

      player_id = hd(ctx.table.participants).player_id
      view = GameStateBuilder.build(ctx.table.id, player_id)

      # After pre-flop completes, pot should have blinds
      assert view.total_pot == 40  # SB called to 20, BB already 20
    end

    test "participant bet_this_round is tracked", ctx do
      player_id = hd(ctx.table.participants).player_id
      view = GameStateBuilder.build(ctx.table.id, player_id)

      bets = Enum.map(view.participants, & &1.bet_this_round)
      assert Enum.member?(bets, 10)  # small blind
      assert Enum.member?(bets, 20)  # big blind
    end
  end

  describe "build/3 - current turn tracking" do
    setup ctx do
      ctx
      |> exec(:create_table,
        type: :six_max,
        settings: %{
          small_blind: 10,
          big_blind: 20,
          starting_stack: 1000,
          timeout_seconds: 60
        }
      )
      |> exec(:add_participants, generate_players: 2)
      |> exec(:start_table)
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
      |> exec(:create_table,
        type: :six_max,
        settings: %{
          small_blind: 10,
          big_blind: 20,
          starting_stack: 1000,
          timeout_seconds: 60
        }
      )
      |> exec(:add_participants, generate_players: 2)
      |> exec(:start_table)
    end

    test "timeout_seconds is from settings", ctx do
      player_id = hd(ctx.table.participants).player_id
      view = GameStateBuilder.build(ctx.table.id, player_id)

      assert view.timeout_seconds == 60
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
      |> exec(:create_table,
        type: :six_max,
        settings: %{
          small_blind: 10,
          big_blind: 20,
          starting_stack: 1000,
          timeout_seconds: 60
        }
      )
      |> exec(:add_participants, generate_players: 2)
    end

    test "no community cards pre-flop", ctx do
      ctx = ctx |> exec(:start_table)
      player_id = hd(ctx.table.participants).player_id
      view = GameStateBuilder.build(ctx.table.id, player_id)

      assert view.community_cards == []
    end

    test "3 community cards on flop", ctx do
      ctx =
        ctx
        |> exec(:start_table)
        |> exec(:call_hand)
        |> exec(:check_hand)

      player_id = hd(ctx.table.participants).player_id
      view = GameStateBuilder.build(ctx.table.id, player_id)

      assert length(view.community_cards) == 3
    end
  end

  describe "build/3 - folded player" do
    setup ctx do
      ctx
      |> exec(:create_table,
        type: :six_max,
        settings: %{
          small_blind: 10,
          big_blind: 20,
          starting_stack: 1000,
          timeout_seconds: 60
        }
      )
      |> exec(:add_participants, generate_players: 3)
      |> exec(:start_table)
    end

    test "folded player sees empty hole cards", ctx do
      # Get the acting participant before fold
      folded_participant_id = ctx.table.round.participant_to_act_id
      folded_participant =
        Enum.find(ctx.table.participants, &(&1.id == folded_participant_id))

      # First player folds
      _ctx = ctx |> exec(:fold_hand)

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
      |> exec(:create_table,
        type: :six_max,
        settings: %{
          small_blind: 10,
          big_blind: 20,
          starting_stack: 1000,
          timeout_seconds: 60
        }
      )
      |> exec(:add_participants, generate_players: 2)
      |> exec(:start_table)
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

      # Small blind should have 990 chips, big blind should have 980
      chips = Enum.map(view.participants, & &1.chips)
      assert Enum.member?(chips, 990)  # 1000 - 10 (small blind)
      assert Enum.member?(chips, 980)  # 1000 - 20 (big blind)
    end
  end

  describe "build/3 - paused table" do
    setup ctx do
      ctx
      |> exec(:create_table,
        type: :six_max,
        settings: %{
          small_blind: 10,
          big_blind: 20,
          starting_stack: 1000,
          timeout_seconds: 60
        }
      )
      |> exec(:add_participants, generate_players: 2)
      |> exec(:start_table)
    end

    test "paused table shows empty community cards and hole cards", ctx do
      # Sit out to pause the table (with 2 players, sitting out + fold = pause)
      _ctx = ctx |> exec(:sit_out) |> exec(:fold_hand)

      table = Poker.SeedFactorySchema.aggregate_state(:table, ctx.table.id)
      assert table.status == :paused

      player_id = hd(table.participants).player_id
      view = GameStateBuilder.build(ctx.table.id, player_id)

      assert view.table_status == :paused
      assert view.community_cards == []
      assert Enum.all?(view.participants, &(&1.hole_cards == []))
    end
  end

  describe "build/3 - calculate_actions option" do
    setup ctx do
      ctx
      |> exec(:create_table,
        type: :six_max,
        settings: %{
          small_blind: 10,
          big_blind: 20,
          starting_stack: 1000,
          timeout_seconds: 60
        }
      )
      |> exec(:add_participants, generate_players: 2)
      |> exec(:start_table)
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

  describe "replay_events/2 - basic replay without hand history" do
    setup ctx do
      ctx
      |> exec(:create_table,
        type: :six_max,
        settings: %{
          small_blind: 10,
          big_blind: 20,
          starting_stack: 1000,
          timeout_seconds: 60
        }
      )
      |> exec(:add_participants, generate_players: 2)
    end

    test "replays events from beginning and matches Commanded aggregate state", ctx do
      %{aggregate: replayed_aggregate} = GameStateBuilder.replay_events(ctx.table.id)

      # Get Commanded aggregate state directly
      commanded_aggregate = get_commanded_aggregate(ctx.table.id)

      assert replayed_aggregate == commanded_aggregate
    end

    test "returns correct latest_version", ctx do
      result = GameStateBuilder.replay_events(ctx.table.id)

      assert %{latest_version: latest_version} = result
      assert is_integer(latest_version)
      assert latest_version > 0
    end
  end

  describe "replay_events/2 - replay with hand history checkpoint" do
    setup ctx do
      ctx
      |> exec(:create_table,
        type: :six_max,
        settings: %{
          small_blind: 10,
          big_blind: 20,
          starting_stack: 1000,
          timeout_seconds: 60
        }
      )
      |> exec(:add_participants, generate_players: 2)
      |> exec(:start_table)
    end

    test "replayed aggregate matches Commanded aggregate state after hand started", ctx do
      %{aggregate: replayed_aggregate} = GameStateBuilder.replay_events(ctx.table.id)
      commanded_aggregate = get_commanded_aggregate(ctx.table.id)

      assert replayed_aggregate == commanded_aggregate
    end

    test "replayed aggregate matches after call action", ctx do
      ctx = ctx |> exec(:call_hand)

      %{aggregate: replayed_aggregate} = GameStateBuilder.replay_events(ctx.table.id)
      commanded_aggregate = get_commanded_aggregate(ctx.table.id)

      assert replayed_aggregate == commanded_aggregate
    end

    test "replayed aggregate matches after raise action", ctx do
      ctx = ctx |> exec(:raise_hand, amount: 60)

      %{aggregate: replayed_aggregate} = GameStateBuilder.replay_events(ctx.table.id)
      commanded_aggregate = get_commanded_aggregate(ctx.table.id)

      assert replayed_aggregate == commanded_aggregate
    end

    test "replayed aggregate matches after fold action", ctx do
      ctx = ctx |> exec(:fold_hand)

      %{aggregate: replayed_aggregate} = GameStateBuilder.replay_events(ctx.table.id)
      commanded_aggregate = get_commanded_aggregate(ctx.table.id)

      assert replayed_aggregate == commanded_aggregate
    end

    test "replayed aggregate matches after completing pre-flop round", ctx do
      ctx =
        ctx
        |> exec(:call_hand)
        |> exec(:check_hand)

      %{aggregate: replayed_aggregate} = GameStateBuilder.replay_events(ctx.table.id)
      commanded_aggregate = get_commanded_aggregate(ctx.table.id)

      assert replayed_aggregate == commanded_aggregate
    end
  end

  describe "replay_events/2 - incremental replay with since_version" do
    setup ctx do
      ctx
      |> exec(:create_table,
        type: :six_max,
        settings: %{
          small_blind: 10,
          big_blind: 20,
          starting_stack: 1000,
          timeout_seconds: 60
        }
      )
      |> exec(:add_participants, generate_players: 2)
      |> exec(:start_table)
    end

    test "returns aggregate at specific version", ctx do
      # Get latest version first
      %{latest_version: latest_version} = GameStateBuilder.replay_events(ctx.table.id)

      # Replay to a specific version
      result = GameStateBuilder.replay_events(ctx.table.id, latest_version)

      assert %{aggregate: aggregate, latest_version: ^latest_version} = result
      assert aggregate.id == ctx.table.id
    end

    test "incremental replay produces same state as full replay", ctx do
      # Full replay
      %{aggregate: full_aggregate, latest_version: latest_version} =
        GameStateBuilder.replay_events(ctx.table.id)

      # Incremental replay to same version
      %{aggregate: incremental_aggregate} =
        GameStateBuilder.replay_events(ctx.table.id, latest_version)

      assert full_aggregate == incremental_aggregate
    end
  end

  describe "replay_events/2 - multi-player game consistency" do
    setup ctx do
      ctx
      |> exec(:create_table,
        type: :six_max,
        settings: %{
          small_blind: 10,
          big_blind: 20,
          starting_stack: 1000,
          timeout_seconds: 60
        }
      )
      |> exec(:add_participants, generate_players: 3)
      |> exec(:start_table)
    end

    test "replayed aggregate matches throughout betting sequence", ctx do
      # Initial state
      assert_replay_matches_commanded(ctx.table.id)

      # After first call
      ctx = ctx |> exec(:call_hand)
      assert_replay_matches_commanded(ctx.table.id)

      # After second call
      ctx = ctx |> exec(:call_hand)
      assert_replay_matches_commanded(ctx.table.id)

      # After check to complete pre-flop
      ctx = ctx |> exec(:check_hand)
      assert_replay_matches_commanded(ctx.table.id)
    end

    test "replayed aggregate matches after all-in", ctx do
      ctx = ctx |> exec(:all_in_hand)

      %{aggregate: replayed_aggregate} = GameStateBuilder.replay_events(ctx.table.id)
      commanded_aggregate = get_commanded_aggregate(ctx.table.id)

      assert replayed_aggregate == commanded_aggregate
    end
  end

  # Helper to get Commanded aggregate state directly
  defp get_commanded_aggregate(table_id) do
    Poker.TestSupport.ProcessManagerAwaiter.wait_to_settle()

    Commanded.Aggregates.Aggregate.aggregate_state(
      Poker.App,
      Poker.Tables.Aggregates.Table,
      "table-" <> table_id
    )
  end

  # Helper to assert replayed aggregate matches Commanded state
  defp assert_replay_matches_commanded(table_id) do
    %{aggregate: replayed_aggregate} = GameStateBuilder.replay_events(table_id)
    commanded_aggregate = get_commanded_aggregate(table_id)

    assert replayed_aggregate == commanded_aggregate
  end
end
