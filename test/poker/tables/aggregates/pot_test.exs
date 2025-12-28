defmodule Poker.Tables.Aggregates.PotTest do
  use ExUnit.Case

  alias Poker.Tables.Aggregates.Table.Pot

  describe "recalculate_pots/1 - Simple Pots" do
    test "single pot with all players contributing equally" do
      participant_hands = [
        %{participant_id: "p1", total_bet_this_hand: 100, status: :playing},
        %{participant_id: "p2", total_bet_this_hand: 100, status: :playing},
        %{participant_id: "p3", total_bet_this_hand: 100, status: :playing}
      ]

      pots = Pot.recalculate_pots(participant_hands)

      assert length(pots) == 1
      assert hd(pots).type == :main
      assert hd(pots).amount == 300
      assert hd(pots).bet_amount == 100
      assert hd(pots).contributing_participant_ids == ["p1", "p2", "p3"]
    end

    test "single pot with two players" do
      participant_hands = [
        %{participant_id: "p1", total_bet_this_hand: 50, status: :playing},
        %{participant_id: "p2", total_bet_this_hand: 50, status: :playing}
      ]

      pots = Pot.recalculate_pots(participant_hands)

      assert length(pots) == 1
      assert hd(pots).type == :main
      assert hd(pots).amount == 100
      assert hd(pots).contributing_participant_ids == ["p1", "p2"]
    end

    test "empty pot when no bets placed" do
      participant_hands = [
        %{participant_id: "p1", total_bet_this_hand: 0, status: :playing},
        %{participant_id: "p2", total_bet_this_hand: 0, status: :playing}
      ]

      pots = Pot.recalculate_pots(participant_hands)

      assert pots == []
    end
  end

  describe "recalculate_pots/1 - Single Side Pot" do
    test "one player all-in for less creates side pot" do
      participant_hands = [
        %{participant_id: "p1", total_bet_this_hand: 50, status: :playing},
        %{participant_id: "p2", total_bet_this_hand: 100, status: :playing},
        %{participant_id: "p3", total_bet_this_hand: 100, status: :playing}
      ]

      pots = Pot.recalculate_pots(participant_hands)

      assert length(pots) == 2

      # Main pot: 50 * 3 = 150
      main_pot = Enum.at(pots, 0)
      assert main_pot.type == :main
      assert main_pot.amount == 150
      assert main_pot.bet_amount == 50
      assert main_pot.contributing_participant_ids == ["p1", "p2", "p3"]

      # Side pot: 50 * 2 = 100
      side_pot = Enum.at(pots, 1)
      assert side_pot.type == :side
      assert side_pot.amount == 100
      assert side_pot.bet_amount == 50
      assert side_pot.contributing_participant_ids == ["p2", "p3"]
    end

    test "heads-up with one all-in for less" do
      participant_hands = [
        %{participant_id: "p1", total_bet_this_hand: 30, status: :playing},
        %{participant_id: "p2", total_bet_this_hand: 100, status: :playing}
      ]

      pots = Pot.recalculate_pots(participant_hands)

      assert length(pots) == 2

      # Main pot: 30 * 2 = 60
      main_pot = Enum.at(pots, 0)
      assert main_pot.type == :main
      assert main_pot.amount == 60
      assert main_pot.contributing_participant_ids == ["p1", "p2"]

      # Side pot: 70 * 1 = 70
      side_pot = Enum.at(pots, 1)
      assert side_pot.type == :side
      assert side_pot.amount == 70
      assert side_pot.contributing_participant_ids == ["p2"]
    end
  end

  describe "recalculate_pots/1 - Multiple Side Pots" do
    test "two players all-in at different amounts creates two side pots" do
      participant_hands = [
        %{participant_id: "p1", total_bet_this_hand: 50, status: :playing},
        %{participant_id: "p2", total_bet_this_hand: 100, status: :playing},
        %{participant_id: "p3", total_bet_this_hand: 200, status: :playing},
        %{participant_id: "p4", total_bet_this_hand: 200, status: :playing}
      ]

      pots = Pot.recalculate_pots(participant_hands)

      assert length(pots) == 3

      # Main pot: 50 * 4 = 200
      main_pot = Enum.at(pots, 0)
      assert main_pot.type == :main
      assert main_pot.amount == 200
      assert main_pot.bet_amount == 50
      assert main_pot.contributing_participant_ids == ["p1", "p2", "p3", "p4"]

      # Side pot 1: 50 * 3 = 150
      side_pot1 = Enum.at(pots, 1)
      assert side_pot1.type == :side
      assert side_pot1.amount == 150
      assert side_pot1.bet_amount == 50
      assert side_pot1.contributing_participant_ids == ["p2", "p3", "p4"]

      # Side pot 2: 100 * 2 = 200
      side_pot2 = Enum.at(pots, 2)
      assert side_pot2.type == :side
      assert side_pot2.amount == 200
      assert side_pot2.bet_amount == 100
      assert side_pot2.contributing_participant_ids == ["p3", "p4"]
    end

    test "three players all-in at different amounts" do
      participant_hands = [
        %{participant_id: "p1", total_bet_this_hand: 25, status: :playing},
        %{participant_id: "p2", total_bet_this_hand: 75, status: :playing},
        %{participant_id: "p3", total_bet_this_hand: 150, status: :playing},
        %{participant_id: "p4", total_bet_this_hand: 150, status: :playing}
      ]

      pots = Pot.recalculate_pots(participant_hands)

      assert length(pots) == 3

      # Main pot: 25 * 4 = 100
      main_pot = Enum.at(pots, 0)
      assert main_pot.type == :main
      assert main_pot.amount == 100
      assert main_pot.contributing_participant_ids == ["p1", "p2", "p3", "p4"]

      # Side pot 1: 50 * 3 = 150
      side_pot1 = Enum.at(pots, 1)
      assert side_pot1.type == :side
      assert side_pot1.amount == 150
      assert side_pot1.contributing_participant_ids == ["p2", "p3", "p4"]

      # Side pot 2: 75 * 2 = 150
      side_pot2 = Enum.at(pots, 2)
      assert side_pot2.type == :side
      assert side_pot2.amount == 150
      assert side_pot2.contributing_participant_ids == ["p3", "p4"]
    end

    test "complex scenario with 6 players at different bet levels" do
      participant_hands = [
        %{participant_id: "p1", total_bet_this_hand: 10, status: :playing},
        %{participant_id: "p2", total_bet_this_hand: 20, status: :playing},
        %{participant_id: "p3", total_bet_this_hand: 30, status: :playing},
        %{participant_id: "p4", total_bet_this_hand: 100, status: :playing},
        %{participant_id: "p5", total_bet_this_hand: 100, status: :playing},
        %{participant_id: "p6", total_bet_this_hand: 100, status: :playing}
      ]

      pots = Pot.recalculate_pots(participant_hands)

      assert length(pots) == 4

      # Main pot: 10 * 6 = 60
      assert Enum.at(pots, 0).amount == 60
      assert length(Enum.at(pots, 0).contributing_participant_ids) == 6

      # Side pot 1: 10 * 5 = 50
      assert Enum.at(pots, 1).amount == 50
      assert length(Enum.at(pots, 1).contributing_participant_ids) == 5

      # Side pot 2: 10 * 4 = 40
      assert Enum.at(pots, 2).amount == 40
      assert length(Enum.at(pots, 2).contributing_participant_ids) == 4

      # Side pot 3: 70 * 3 = 210
      assert Enum.at(pots, 3).amount == 210
      assert length(Enum.at(pots, 3).contributing_participant_ids) == 3
    end
  end

  describe "recalculate_pots/1 - Folded Players" do
    test "folded players excluded from pot eligibility" do
      participant_hands = [
        %{participant_id: "p1", total_bet_this_hand: 50, status: :folded},
        %{participant_id: "p2", total_bet_this_hand: 100, status: :playing},
        %{participant_id: "p3", total_bet_this_hand: 100, status: :playing}
      ]

      pots = Pot.recalculate_pots(participant_hands)

      assert length(pots) == 2

      # Main pot includes folded player's bet but they're not eligible
      main_pot = Enum.at(pots, 0)
      assert main_pot.amount == 150
      assert main_pot.contributing_participant_ids == ["p2", "p3"]

      # Side pot only from active players
      side_pot = Enum.at(pots, 1)
      assert side_pot.amount == 100
      assert side_pot.contributing_participant_ids == ["p2", "p3"]
    end

    test "multiple folded players at different bet levels" do
      participant_hands = [
        %{participant_id: "p1", total_bet_this_hand: 25, status: :folded},
        %{participant_id: "p2", total_bet_this_hand: 50, status: :folded},
        %{participant_id: "p3", total_bet_this_hand: 100, status: :playing},
        %{participant_id: "p4", total_bet_this_hand: 100, status: :playing}
      ]

      pots = Pot.recalculate_pots(participant_hands)

      assert length(pots) == 3

      # Only active players are eligible
      Enum.each(pots, fn pot ->
        assert pot.contributing_participant_ids == ["p3", "p4"]
      end)
    end

    test "all but one player folded" do
      participant_hands = [
        %{participant_id: "p1", total_bet_this_hand: 50, status: :folded},
        %{participant_id: "p2", total_bet_this_hand: 50, status: :folded},
        %{participant_id: "p3", total_bet_this_hand: 50, status: :playing}
      ]

      pots = Pot.recalculate_pots(participant_hands)

      assert length(pots) == 1
      assert hd(pots).amount == 150
      assert hd(pots).contributing_participant_ids == ["p3"]
    end
  end

  describe "recalculate_pots/1 - Edge Cases" do
    test "player with zero bet not included in pot" do
      participant_hands = [
        %{participant_id: "p1", total_bet_this_hand: 0, status: :playing},
        %{participant_id: "p2", total_bet_this_hand: 100, status: :playing},
        %{participant_id: "p3", total_bet_this_hand: 100, status: :playing}
      ]

      pots = Pot.recalculate_pots(participant_hands)

      assert length(pots) == 1
      assert hd(pots).amount == 200
      assert hd(pots).contributing_participant_ids == ["p2", "p3"]
    end

    test "mixed zero and non-zero bets" do
      participant_hands = [
        %{participant_id: "p1", total_bet_this_hand: 0, status: :playing},
        %{participant_id: "p2", total_bet_this_hand: 0, status: :playing},
        %{participant_id: "p3", total_bet_this_hand: 50, status: :playing},
        %{participant_id: "p4", total_bet_this_hand: 100, status: :playing}
      ]

      pots = Pot.recalculate_pots(participant_hands)

      assert length(pots) == 2

      # Main pot from players who bet
      main_pot = Enum.at(pots, 0)
      assert main_pot.amount == 100
      assert main_pot.contributing_participant_ids == ["p3", "p4"]

      # Side pot
      side_pot = Enum.at(pots, 1)
      assert side_pot.amount == 50
      assert side_pot.contributing_participant_ids == ["p4"]
    end

    test "single player with bet" do
      participant_hands = [
        %{participant_id: "p1", total_bet_this_hand: 100, status: :playing},
        %{participant_id: "p2", total_bet_this_hand: 0, status: :folded},
        %{participant_id: "p3", total_bet_this_hand: 0, status: :folded}
      ]

      pots = Pot.recalculate_pots(participant_hands)

      assert length(pots) == 1
      assert hd(pots).amount == 100
      assert hd(pots).contributing_participant_ids == ["p1"]
    end

    test "all players bet same amount" do
      participant_hands = [
        %{participant_id: "p1", total_bet_this_hand: 200, status: :playing},
        %{participant_id: "p2", total_bet_this_hand: 200, status: :playing},
        %{participant_id: "p3", total_bet_this_hand: 200, status: :playing},
        %{participant_id: "p4", total_bet_this_hand: 200, status: :playing}
      ]

      pots = Pot.recalculate_pots(participant_hands)

      assert length(pots) == 1
      assert hd(pots).type == :main
      assert hd(pots).amount == 800
      assert length(hd(pots).contributing_participant_ids) == 4
    end

    test "tiny bet amounts" do
      participant_hands = [
        %{participant_id: "p1", total_bet_this_hand: 1, status: :playing},
        %{participant_id: "p2", total_bet_this_hand: 2, status: :playing},
        %{participant_id: "p3", total_bet_this_hand: 3, status: :playing}
      ]

      pots = Pot.recalculate_pots(participant_hands)

      assert length(pots) == 3

      assert Enum.at(pots, 0).amount == 3
      assert Enum.at(pots, 1).amount == 2
      assert Enum.at(pots, 2).amount == 1
    end
  end

  describe "recalculate_pots/1 - Real Game Scenarios" do
    test "pre-flop with blinds and one caller" do
      participant_hands = [
        # small blind
        %{participant_id: "p1", total_bet_this_hand: 10, status: :playing},
        # big blind
        %{participant_id: "p2", total_bet_this_hand: 20, status: :playing},
        # caller
        %{participant_id: "p3", total_bet_this_hand: 20, status: :playing},
        %{participant_id: "p4", total_bet_this_hand: 0, status: :folded}
      ]

      pots = Pot.recalculate_pots(participant_hands)

      assert length(pots) == 2

      # Main pot: 10 * 3 = 30
      assert Enum.at(pots, 0).amount == 30

      # Side pot: 10 * 2 = 20
      assert Enum.at(pots, 1).amount == 20
    end

    test "all-in showdown with varying stacks" do
      participant_hands = [
        %{participant_id: "p1", total_bet_this_hand: 150, status: :playing},
        %{participant_id: "p2", total_bet_this_hand: 500, status: :playing},
        %{participant_id: "p3", total_bet_this_hand: 500, status: :playing}
      ]

      pots = Pot.recalculate_pots(participant_hands)

      assert length(pots) == 2

      # Main pot: 150 * 3 = 450
      main_pot = Enum.at(pots, 0)
      assert main_pot.amount == 450
      assert length(main_pot.contributing_participant_ids) == 3

      # Side pot: 350 * 2 = 700
      side_pot = Enum.at(pots, 1)
      assert side_pot.amount == 700
      assert length(side_pot.contributing_participant_ids) == 2
    end

    test "tournament bubble scenario with multiple all-ins" do
      participant_hands = [
        # short stack all-in
        %{participant_id: "p1", total_bet_this_hand: 50, status: :playing},
        # medium stack all-in
        %{participant_id: "p2", total_bet_this_hand: 100, status: :playing},
        # big stack all-in
        %{participant_id: "p3", total_bet_this_hand: 300, status: :playing},
        # big stack all-in
        %{participant_id: "p4", total_bet_this_hand: 300, status: :playing},
        %{participant_id: "p5", total_bet_this_hand: 0, status: :folded}
      ]

      pots = Pot.recalculate_pots(participant_hands)

      assert length(pots) == 3

      # Main pot: 50 * 4 = 200 (all active players)
      assert Enum.at(pots, 0).amount == 200
      assert length(Enum.at(pots, 0).contributing_participant_ids) == 4

      # Side pot 1: 50 * 3 = 150
      assert Enum.at(pots, 1).amount == 150
      assert length(Enum.at(pots, 1).contributing_participant_ids) == 3

      # Side pot 2: 200 * 2 = 400
      assert Enum.at(pots, 2).amount == 400
      assert length(Enum.at(pots, 2).contributing_participant_ids) == 2
    end
  end
end
