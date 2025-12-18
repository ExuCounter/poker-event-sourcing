defmodule Poker.Tables.Aggregates.Table.Apply.Round do
  @moduledoc """
  Handles round event application.
  """

  alias Poker.Tables.Aggregates.Table
  alias Poker.Tables.Events.{RoundStarted, RoundCompleted}

  def apply(
        %Table{participant_hands: participant_hands, community_cards: community_cards} = table,
        %RoundStarted{} = event
      ) do
    round = %{
      id: event.id,
      type: event.type,
      acted_participant_ids: [],
      participant_to_act_id: nil
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

  def apply(%Table{} = table, %RoundCompleted{}) do
    updated_participant_hands = Enum.map(table.participant_hands, &%{&1 | bet_this_round: 0})

    %Table{table | participant_hands: updated_participant_hands}
  end
end
