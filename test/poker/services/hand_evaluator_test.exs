defmodule Poker.Services.HandEvaluatorTest do
  use ExUnit.Case, async: true

  alias Poker.Services.HandEvaluator.Implementation, as: HandEvaluator

  describe "determine_winners/2 - Royal Flush" do
    test "royal flush beats straight flush" do
      participant_hands = [
        %{
          participant_id: "p1",
          hole_cards: [%{rank: :A, suit: :hearts}, %{rank: :K, suit: :hearts}]
        },
        %{
          participant_id: "p2",
          hole_cards: [%{rank: 9, suit: :spades}, %{rank: 8, suit: :spades}]
        }
      ]

      community_cards = [
        %{rank: :Q, suit: :hearts},
        %{rank: :J, suit: :hearts},
        %{rank: :T, suit: :hearts},
        %{rank: 7, suit: :spades},
        %{rank: 6, suit: :spades}
      ]

      winners = HandEvaluator.determine_winners(participant_hands, community_cards)

      assert length(winners) == 1
      assert hd(winners).participant_id == "p1"
      assert hd(winners).hand_rank == [:straight_flush, :A]
    end

    test "royal flush vs four of a kind" do
      participant_hands = [
        %{
          participant_id: "p1",
          hole_cards: [%{rank: :A, suit: :diamonds}, %{rank: :K, suit: :diamonds}]
        },
        %{
          participant_id: "p2",
          hole_cards: [%{rank: :Q, suit: :clubs}, %{rank: :Q, suit: :spades}]
        }
      ]

      community_cards = [
        %{rank: :Q, suit: :diamonds},
        %{rank: :J, suit: :diamonds},
        %{rank: :T, suit: :diamonds},
        %{rank: :Q, suit: :hearts},
        %{rank: 2, suit: :clubs}
      ]

      winners = HandEvaluator.determine_winners(participant_hands, community_cards)

      assert length(winners) == 1
      assert hd(winners).participant_id == "p1"
      assert hd(winners).hand_rank == [:straight_flush, :A]
    end
  end

  describe "determine_winners/2 - Straight Flush" do
    test "higher straight flush beats lower straight flush" do
      participant_hands = [
        %{
          participant_id: "p1",
          hole_cards: [%{rank: :K, suit: :hearts}, %{rank: :Q, suit: :hearts}]
        },
        %{
          participant_id: "p2",
          hole_cards: [%{rank: 8, suit: :spades}, %{rank: 7, suit: :spades}]
        }
      ]

      community_cards = [
        %{rank: :J, suit: :hearts},
        %{rank: :T, suit: :hearts},
        %{rank: 9, suit: :hearts},
        %{rank: 6, suit: :spades},
        %{rank: 5, suit: :spades}
      ]

      winners = HandEvaluator.determine_winners(participant_hands, community_cards)

      assert length(winners) == 1
      assert hd(winners).participant_id == "p1"
      assert hd(winners).hand_rank == [:straight_flush, :K]
    end

    test "straight flush beats four of a kind" do
      participant_hands = [
        %{
          participant_id: "p1",
          hole_cards: [%{rank: 9, suit: :clubs}, %{rank: 8, suit: :clubs}]
        },
        %{
          participant_id: "p2",
          hole_cards: [%{rank: :A, suit: :hearts}, %{rank: :A, suit: :spades}]
        }
      ]

      community_cards = [
        %{rank: 7, suit: :clubs},
        %{rank: 6, suit: :clubs},
        %{rank: 5, suit: :clubs},
        %{rank: :A, suit: :diamonds},
        %{rank: :A, suit: :clubs}
      ]

      winners = HandEvaluator.determine_winners(participant_hands, community_cards)

      assert length(winners) == 1
      assert hd(winners).participant_id == "p1"
      assert hd(winners).hand_rank == [:straight_flush, 9]
    end
  end

  describe "determine_winners/2 - Four of a Kind" do
    test "four of a kind beats full house" do
      participant_hands = [
        %{
          participant_id: "p1",
          hole_cards: [%{rank: :K, suit: :hearts}, %{rank: :K, suit: :spades}]
        },
        %{
          participant_id: "p2",
          hole_cards: [%{rank: :Q, suit: :hearts}, %{rank: :Q, suit: :spades}]
        }
      ]

      community_cards = [
        %{rank: :K, suit: :diamonds},
        %{rank: :K, suit: :clubs},
        %{rank: :Q, suit: :diamonds},
        %{rank: 3, suit: :hearts},
        %{rank: 2, suit: :clubs}
      ]

      winners = HandEvaluator.determine_winners(participant_hands, community_cards)

      assert length(winners) == 1
      assert hd(winners).participant_id == "p1"
      assert hd(winners).hand_rank == [:four_of_a_kind, :K, :Q]
    end

    test "higher four of a kind beats lower four of a kind" do
      participant_hands = [
        %{
          participant_id: "p1",
          hole_cards: [%{rank: :A, suit: :hearts}, %{rank: :A, suit: :spades}]
        },
        %{
          participant_id: "p2",
          hole_cards: [%{rank: :K, suit: :hearts}, %{rank: :K, suit: :spades}]
        }
      ]

      community_cards = [
        %{rank: :A, suit: :diamonds},
        %{rank: :A, suit: :clubs},
        %{rank: :K, suit: :diamonds},
        %{rank: :K, suit: :clubs},
        %{rank: 2, suit: :clubs}
      ]

      winners = HandEvaluator.determine_winners(participant_hands, community_cards)

      assert length(winners) == 1
      assert hd(winners).participant_id == "p1"
      assert hd(winners).hand_rank == [:four_of_a_kind, :A, :K]
    end
  end

  describe "determine_winners/2 - Full House" do
    test "full house beats flush" do
      participant_hands = [
        %{
          participant_id: "p1",
          hole_cards: [%{rank: :K, suit: :hearts}, %{rank: :K, suit: :spades}]
        },
        %{
          participant_id: "p2",
          hole_cards: [%{rank: :A, suit: :hearts}, %{rank: 9, suit: :hearts}]
        }
      ]

      community_cards = [
        %{rank: :K, suit: :diamonds},
        %{rank: :Q, suit: :hearts},
        %{rank: :Q, suit: :spades},
        %{rank: 7, suit: :hearts},
        %{rank: 2, suit: :hearts}
      ]

      winners = HandEvaluator.determine_winners(participant_hands, community_cards)

      assert length(winners) == 1
      assert hd(winners).participant_id == "p1"
      assert hd(winners).hand_rank == [:full_house, :K, :Q]
    end

    test "higher trips full house beats lower trips full house" do
      participant_hands = [
        %{
          participant_id: "p1",
          hole_cards: [%{rank: :A, suit: :hearts}, %{rank: :A, suit: :spades}]
        },
        %{
          participant_id: "p2",
          hole_cards: [%{rank: :K, suit: :hearts}, %{rank: :K, suit: :spades}]
        }
      ]

      community_cards = [
        %{rank: :A, suit: :diamonds},
        %{rank: :K, suit: :diamonds},
        %{rank: :Q, suit: :hearts},
        %{rank: :Q, suit: :spades},
        %{rank: 2, suit: :clubs}
      ]

      winners = HandEvaluator.determine_winners(participant_hands, community_cards)

      assert length(winners) == 1
      assert hd(winners).participant_id == "p1"
      assert hd(winners).hand_rank == [:full_house, :A, :Q]
    end

    test "same trips, higher pair full house wins" do
      participant_hands = [
        %{
          participant_id: "p1",
          hole_cards: [%{rank: :K, suit: :hearts}, %{rank: :K, suit: :spades}]
        },
        %{
          participant_id: "p2",
          hole_cards: [%{rank: :Q, suit: :hearts}, %{rank: :Q, suit: :spades}]
        }
      ]

      community_cards = [
        %{rank: :A, suit: :hearts},
        %{rank: :A, suit: :diamonds},
        %{rank: :A, suit: :clubs},
        %{rank: 3, suit: :hearts},
        %{rank: 2, suit: :clubs}
      ]

      winners = HandEvaluator.determine_winners(participant_hands, community_cards)

      assert length(winners) == 1
      assert hd(winners).participant_id == "p1"
      assert hd(winners).hand_rank == [:full_house, :A, :K]
    end
  end

  describe "determine_winners/2 - Flush" do
    test "flush beats straight" do
      participant_hands = [
        %{
          participant_id: "p1",
          hole_cards: [%{rank: :A, suit: :hearts}, %{rank: :K, suit: :hearts}]
        },
        %{
          participant_id: "p2",
          hole_cards: [%{rank: 9, suit: :spades}, %{rank: 8, suit: :diamonds}]
        }
      ]

      community_cards = [
        %{rank: 7, suit: :hearts},
        %{rank: 5, suit: :hearts},
        %{rank: 3, suit: :hearts},
        %{rank: :T, suit: :clubs},
        %{rank: :J, suit: :hearts}
      ]

      winners = HandEvaluator.determine_winners(participant_hands, community_cards)

      assert length(winners) == 1
      assert hd(winners).participant_id == "p1"
      assert hd(winners).hand_rank == [:flush, :h, :A, :K, :J, 7, 5]
    end

    test "higher flush card wins" do
      participant_hands = [
        %{
          participant_id: "p1",
          hole_cards: [%{rank: :A, suit: :hearts}, %{rank: 9, suit: :hearts}]
        },
        %{
          participant_id: "p2",
          hole_cards: [%{rank: :K, suit: :hearts}, %{rank: 8, suit: :hearts}]
        }
      ]

      community_cards = [
        %{rank: 7, suit: :hearts},
        %{rank: 5, suit: :hearts},
        %{rank: 3, suit: :hearts},
        %{rank: 2, suit: :spades},
        %{rank: 4, suit: :clubs}
      ]

      winners = HandEvaluator.determine_winners(participant_hands, community_cards)

      assert length(winners) == 1
      assert hd(winners).participant_id == "p1"
      assert hd(winners).hand_rank == [:flush, :h, :A, 9, 7, 5, 3]
    end
  end

  describe "determine_winners/2 - Straight" do
    test "straight beats three of a kind" do
      participant_hands = [
        %{
          participant_id: "p1",
          hole_cards: [%{rank: 9, suit: :hearts}, %{rank: 8, suit: :spades}]
        },
        %{
          participant_id: "p2",
          hole_cards: [%{rank: :K, suit: :hearts}, %{rank: :K, suit: :spades}]
        }
      ]

      community_cards = [
        %{rank: 7, suit: :diamonds},
        %{rank: 6, suit: :clubs},
        %{rank: 5, suit: :hearts},
        %{rank: :K, suit: :diamonds},
        %{rank: 2, suit: :clubs}
      ]

      winners = HandEvaluator.determine_winners(participant_hands, community_cards)

      assert length(winners) == 1
      assert hd(winners).participant_id == "p1"
      assert hd(winners).hand_rank == [:straight, 9]
    end

    test "higher straight beats lower straight" do
      participant_hands = [
        %{
          participant_id: "p1",
          hole_cards: [%{rank: :J, suit: :hearts}, %{rank: :T, suit: :spades}]
        },
        %{
          participant_id: "p2",
          hole_cards: [%{rank: 6, suit: :hearts}, %{rank: 5, suit: :spades}]
        }
      ]

      community_cards = [
        %{rank: 9, suit: :diamonds},
        %{rank: 8, suit: :clubs},
        %{rank: 7, suit: :hearts},
        %{rank: 3, suit: :diamonds},
        %{rank: 2, suit: :clubs}
      ]

      winners = HandEvaluator.determine_winners(participant_hands, community_cards)

      assert length(winners) == 1
      assert hd(winners).participant_id == "p1"
      assert hd(winners).hand_rank == [:straight, :J]
    end

    test "ace low straight (wheel)" do
      participant_hands = [
        %{
          participant_id: "p1",
          hole_cards: [%{rank: :A, suit: :hearts}, %{rank: 2, suit: :spades}]
        },
        %{
          participant_id: "p2",
          hole_cards: [%{rank: :K, suit: :hearts}, %{rank: :Q, suit: :spades}]
        }
      ]

      community_cards = [
        %{rank: 5, suit: :diamonds},
        %{rank: 4, suit: :clubs},
        %{rank: 3, suit: :hearts},
        %{rank: :J, suit: :diamonds},
        %{rank: :T, suit: :clubs}
      ]

      winners = HandEvaluator.determine_winners(participant_hands, community_cards)

      assert length(winners) == 1
      assert hd(winners).participant_id == "p1"
      assert hd(winners).hand_rank == [:straight, 5]
    end
  end

  describe "determine_winners/2 - Three of a Kind" do
    test "three of a kind beats two pair" do
      participant_hands = [
        %{
          participant_id: "p1",
          hole_cards: [%{rank: :K, suit: :hearts}, %{rank: :K, suit: :spades}]
        },
        %{
          participant_id: "p2",
          hole_cards: [%{rank: :Q, suit: :hearts}, %{rank: :J, suit: :spades}]
        }
      ]

      community_cards = [
        %{rank: :K, suit: :diamonds},
        %{rank: :Q, suit: :diamonds},
        %{rank: :J, suit: :hearts},
        %{rank: 9, suit: :hearts},
        %{rank: 2, suit: :clubs}
      ]

      winners = HandEvaluator.determine_winners(participant_hands, community_cards)

      assert length(winners) == 1
      assert hd(winners).participant_id == "p1"
      assert hd(winners).hand_rank == [:three_of_a_kind, :K, :Q, :J]
    end

    test "higher three of a kind wins" do
      participant_hands = [
        %{
          participant_id: "p1",
          hole_cards: [%{rank: :A, suit: :hearts}, %{rank: :A, suit: :spades}]
        },
        %{
          participant_id: "p2",
          hole_cards: [%{rank: :K, suit: :hearts}, %{rank: :K, suit: :spades}]
        }
      ]

      community_cards = [
        %{rank: :A, suit: :diamonds},
        %{rank: :K, suit: :diamonds},
        %{rank: 7, suit: :hearts},
        %{rank: 5, suit: :clubs},
        %{rank: 2, suit: :clubs}
      ]

      winners = HandEvaluator.determine_winners(participant_hands, community_cards)

      assert length(winners) == 1
      assert hd(winners).participant_id == "p1"
      assert hd(winners).hand_rank == [:three_of_a_kind, :A, :K, 7]
    end
  end

  describe "determine_winners/2 - Two Pair" do
    test "two pair beats one pair" do
      participant_hands = [
        %{
          participant_id: "p1",
          hole_cards: [%{rank: :K, suit: :hearts}, %{rank: :Q, suit: :spades}]
        },
        %{
          participant_id: "p2",
          hole_cards: [%{rank: :A, suit: :hearts}, %{rank: 9, suit: :spades}]
        }
      ]

      community_cards = [
        %{rank: :K, suit: :diamonds},
        %{rank: :Q, suit: :diamonds},
        %{rank: :A, suit: :clubs},
        %{rank: 7, suit: :hearts},
        %{rank: 2, suit: :clubs}
      ]

      winners = HandEvaluator.determine_winners(participant_hands, community_cards)

      assert length(winners) == 1
      assert hd(winners).participant_id == "p1"
      assert hd(winners).hand_rank == [:two_pair, :K, :Q, 7]
    end

    test "higher top pair wins" do
      participant_hands = [
        %{
          participant_id: "p1",
          hole_cards: [%{rank: :A, suit: :hearts}, %{rank: :K, suit: :spades}]
        },
        %{
          participant_id: "p2",
          hole_cards: [%{rank: :Q, suit: :hearts}, %{rank: :J, suit: :spades}]
        }
      ]

      community_cards = [
        %{rank: :A, suit: :diamonds},
        %{rank: :K, suit: :diamonds},
        %{rank: :Q, suit: :clubs},
        %{rank: :J, suit: :hearts},
        %{rank: 2, suit: :clubs}
      ]

      winners = HandEvaluator.determine_winners(participant_hands, community_cards)

      assert length(winners) == 1
      assert hd(winners).participant_id == "p1"
      assert hd(winners).hand_rank == [:two_pair, :A, :K, :Q]
    end

    test "same pairs, higher kicker wins" do
      participant_hands = [
        %{
          participant_id: "p1",
          hole_cards: [%{rank: :A, suit: :hearts}, %{rank: 9, suit: :spades}]
        },
        %{
          participant_id: "p2",
          hole_cards: [%{rank: :K, suit: :hearts}, %{rank: 8, suit: :spades}]
        }
      ]

      community_cards = [
        %{rank: :Q, suit: :diamonds},
        %{rank: :Q, suit: :clubs},
        %{rank: :J, suit: :hearts},
        %{rank: :J, suit: :diamonds},
        %{rank: 2, suit: :clubs}
      ]

      winners = HandEvaluator.determine_winners(participant_hands, community_cards)

      assert length(winners) == 1
      assert hd(winners).participant_id == "p1"
      assert hd(winners).hand_rank == [:two_pair, :Q, :J, 9]
    end
  end

  describe "determine_winners/2 - One Pair" do
    test "one pair beats high card" do
      participant_hands = [
        %{
          participant_id: "p1",
          hole_cards: [%{rank: :K, suit: :hearts}, %{rank: :K, suit: :spades}]
        },
        %{
          participant_id: "p2",
          hole_cards: [%{rank: :A, suit: :hearts}, %{rank: :Q, suit: :spades}]
        }
      ]

      community_cards = [
        %{rank: 9, suit: :diamonds},
        %{rank: 7, suit: :clubs},
        %{rank: 5, suit: :hearts},
        %{rank: 3, suit: :diamonds},
        %{rank: 2, suit: :clubs}
      ]

      winners = HandEvaluator.determine_winners(participant_hands, community_cards)

      assert length(winners) == 1
      assert hd(winners).participant_id == "p1"
      assert hd(winners).hand_rank == [:one_pair, :K, 9, 7, 5]
    end

    test "higher pair wins" do
      participant_hands = [
        %{
          participant_id: "p1",
          hole_cards: [%{rank: :A, suit: :hearts}, %{rank: :A, suit: :spades}]
        },
        %{
          participant_id: "p2",
          hole_cards: [%{rank: :K, suit: :hearts}, %{rank: :K, suit: :spades}]
        }
      ]

      community_cards = [
        %{rank: 9, suit: :diamonds},
        %{rank: 7, suit: :clubs},
        %{rank: 5, suit: :hearts},
        %{rank: 3, suit: :diamonds},
        %{rank: 2, suit: :clubs}
      ]

      winners = HandEvaluator.determine_winners(participant_hands, community_cards)

      assert length(winners) == 1
      assert hd(winners).participant_id == "p1"
      assert hd(winners).hand_rank == [:one_pair, :A, 9, 7, 5]
    end

    test "same pair, higher kicker wins" do
      participant_hands = [
        %{
          participant_id: "p1",
          hole_cards: [%{rank: :K, suit: :hearts}, %{rank: :Q, suit: :spades}]
        },
        %{
          participant_id: "p2",
          hole_cards: [%{rank: :K, suit: :clubs}, %{rank: :J, suit: :spades}]
        }
      ]

      community_cards = [
        %{rank: :K, suit: :diamonds},
        %{rank: 9, suit: :clubs},
        %{rank: 7, suit: :hearts},
        %{rank: 5, suit: :diamonds},
        %{rank: 2, suit: :clubs}
      ]

      winners = HandEvaluator.determine_winners(participant_hands, community_cards)

      assert length(winners) == 1
      assert hd(winners).participant_id == "p1"
      assert hd(winners).hand_rank == [:one_pair, :K, :Q, 9, 7]
    end
  end

  describe "determine_winners/2 - High Card" do
    test "higher high card wins" do
      participant_hands = [
        %{
          participant_id: "p1",
          hole_cards: [%{rank: :A, suit: :hearts}, %{rank: :K, suit: :spades}]
        },
        %{
          participant_id: "p2",
          hole_cards: [%{rank: :Q, suit: :hearts}, %{rank: :J, suit: :spades}]
        }
      ]

      community_cards = [
        %{rank: 9, suit: :diamonds},
        %{rank: 7, suit: :clubs},
        %{rank: 5, suit: :hearts},
        %{rank: 3, suit: :diamonds},
        %{rank: 2, suit: :clubs}
      ]

      winners = HandEvaluator.determine_winners(participant_hands, community_cards)

      assert length(winners) == 1
      assert hd(winners).participant_id == "p1"
      assert hd(winners).hand_rank == [:high_card, :A, :K, 9, 7, 5]
    end

    test "same high card, second card wins" do
      participant_hands = [
        %{
          participant_id: "p1",
          hole_cards: [%{rank: :A, suit: :hearts}, %{rank: :Q, suit: :spades}]
        },
        %{
          participant_id: "p2",
          hole_cards: [%{rank: :A, suit: :clubs}, %{rank: :J, suit: :spades}]
        }
      ]

      community_cards = [
        %{rank: 9, suit: :diamonds},
        %{rank: 7, suit: :clubs},
        %{rank: 5, suit: :hearts},
        %{rank: 3, suit: :diamonds},
        %{rank: 2, suit: :clubs}
      ]

      winners = HandEvaluator.determine_winners(participant_hands, community_cards)

      assert length(winners) == 1
      assert hd(winners).participant_id == "p1"
      assert hd(winners).hand_rank == [:high_card, :A, :Q, 9, 7, 5]
    end
  end

  describe "determine_winners/2 - Multiple Winners (Tie)" do
    test "two players with same straight split pot" do
      participant_hands = [
        %{
          participant_id: "p1",
          hole_cards: [%{rank: 9, suit: :hearts}, %{rank: 2, suit: :spades}]
        },
        %{
          participant_id: "p2",
          hole_cards: [%{rank: 9, suit: :clubs}, %{rank: 3, suit: :diamonds}]
        }
      ]

      community_cards = [
        %{rank: 8, suit: :diamonds},
        %{rank: 7, suit: :clubs},
        %{rank: 6, suit: :hearts},
        %{rank: 5, suit: :diamonds},
        %{rank: 4, suit: :clubs}
      ]

      winners = HandEvaluator.determine_winners(participant_hands, community_cards)

      assert length(winners) == 2
      assert Enum.any?(winners, &(&1.participant_id == "p1"))
      assert Enum.any?(winners, &(&1.participant_id == "p2"))
      assert hd(winners).hand_rank == [:straight, 9]
    end

    test "three players with same flush split pot" do
      participant_hands = [
        %{
          participant_id: "p1",
          hole_cards: [%{rank: 2, suit: :hearts}, %{rank: 3, suit: :clubs}]
        },
        %{
          participant_id: "p2",
          hole_cards: [%{rank: 4, suit: :hearts}, %{rank: 5, suit: :diamonds}]
        },
        %{
          participant_id: "p3",
          hole_cards: [%{rank: 6, suit: :hearts}, %{rank: 7, suit: :spades}]
        }
      ]

      community_cards = [
        %{rank: :A, suit: :hearts},
        %{rank: :K, suit: :hearts},
        %{rank: :Q, suit: :hearts},
        %{rank: :J, suit: :hearts},
        %{rank: :T, suit: :hearts}
      ]

      winners = HandEvaluator.determine_winners(participant_hands, community_cards)

      assert length(winners) == 3
      assert Enum.any?(winners, &(&1.participant_id == "p1"))
      assert Enum.any?(winners, &(&1.participant_id == "p2"))
      assert Enum.any?(winners, &(&1.participant_id == "p3"))
    end

    test "same two pair and kicker split pot" do
      participant_hands = [
        %{
          participant_id: "p1",
          hole_cards: [%{rank: :K, suit: :hearts}, %{rank: :Q, suit: :spades}]
        },
        %{
          participant_id: "p2",
          hole_cards: [%{rank: :K, suit: :clubs}, %{rank: :Q, suit: :diamonds}]
        }
      ]

      community_cards = [
        %{rank: :K, suit: :diamonds},
        %{rank: :Q, suit: :hearts},
        %{rank: :A, suit: :clubs},
        %{rank: 7, suit: :hearts},
        %{rank: 2, suit: :clubs}
      ]

      winners = HandEvaluator.determine_winners(participant_hands, community_cards)

      assert length(winners) == 2
      assert Enum.any?(winners, &(&1.participant_id == "p1"))
      assert Enum.any?(winners, &(&1.participant_id == "p2"))
      assert hd(winners).hand_rank == [:two_pair, :K, :Q, 7]
    end
  end

  describe "determine_winners/2 - Edge Cases" do
    test "multiple players with different hand rankings" do
      participant_hands = [
        %{
          participant_id: "p1",
          hole_cards: [%{rank: :A, suit: :hearts}, %{rank: :K, suit: :hearts}]
        },
        %{
          participant_id: "p2",
          hole_cards: [%{rank: :Q, suit: :clubs}, %{rank: :Q, suit: :spades}]
        },
        %{
          participant_id: "p3",
          hole_cards: [%{rank: 9, suit: :diamonds}, %{rank: 8, suit: :diamonds}]
        },
        %{
          participant_id: "p4",
          hole_cards: [%{rank: 2, suit: :hearts}, %{rank: 3, suit: :clubs}]
        }
      ]

      community_cards = [
        %{rank: :Q, suit: :hearts},
        %{rank: :J, suit: :hearts},
        %{rank: :T, suit: :hearts},
        %{rank: 7, suit: :spades},
        %{rank: 6, suit: :clubs}
      ]

      winners = HandEvaluator.determine_winners(participant_hands, community_cards)

      assert length(winners) == 1
      assert hd(winners).participant_id == "p1"
      assert hd(winners).hand_rank == [:straight_flush, :A]
    end

    test "board plays with no improvement" do
      participant_hands = [
        %{
          participant_id: "p1",
          hole_cards: [%{rank: 2, suit: :spades}, %{rank: 3, suit: :spades}]
        },
        %{
          participant_id: "p2",
          hole_cards: [%{rank: 4, suit: :diamonds}, %{rank: 5, suit: :clubs}]
        }
      ]

      community_cards = [
        %{rank: :A, suit: :hearts},
        %{rank: :A, suit: :diamonds},
        %{rank: :A, suit: :clubs},
        %{rank: :A, suit: :spades},
        %{rank: :K, suit: :hearts}
      ]

      winners = HandEvaluator.determine_winners(participant_hands, community_cards)

      assert length(winners) == 2
      assert Enum.any?(winners, &(&1.participant_id == "p1"))
      assert Enum.any?(winners, &(&1.participant_id == "p2"))
    end
  end
end
