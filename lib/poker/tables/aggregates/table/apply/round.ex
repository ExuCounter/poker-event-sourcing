defmodule Poker.Tables.Aggregates.Table.Apply.Round do
  @moduledoc """
  Applies betting round events to aggregate state.

  Handles the following events:
  - `RoundStarted` - Initializes a new betting round (pre-flop, flop, turn, river)
  - `RoundCompleted` - Resets round-specific state after round ends
  """

  alias Poker.Tables.Aggregates.Table
  alias Poker.Tables.Events.{RoundStarted, RoundCompleted}

  @doc "Initializes a new betting round with community cards."
  def apply(
        %Table{participant_hands: participant_hands, community_cards: community_cards} = table,
        %RoundStarted{} = event
      ) do
    round = %{
      id: event.id,
      type: event.type,
      acted_participant_ids: [],
      participant_to_act_id: nil,
      started_at: nil,
      timeout_seconds: nil
    }

    updated_community_cards = community_cards ++ event.community_cards
    updated_participant_hands = Enum.map(participant_hands, &%{&1 | bet_this_round: 0})

    %Table{
      table
      | participant_hands: updated_participant_hands,
        round: round,
        community_cards: updated_community_cards
    }
  end

  # Resets bet_this_round for all participant hands.
  def apply(%Table{} = table, %RoundCompleted{}) do
    updated_participant_hands = Enum.map(table.participant_hands, &%{&1 | bet_this_round: 0})

    %Table{table | participant_hands: updated_participant_hands}
  end
end
