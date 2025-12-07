defmodule Poker.Tables.Aggregates.Table.Apply.Round do
  @moduledoc """
  Handles round event application.
  """

  alias Poker.Tables.Aggregates.Table
  alias Poker.Tables.Events.{RoundStarted, RoundCompleted}

  def apply(%Table{participants: participants, community_cards: community_cards} = table, %RoundStarted{} = event) do
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

  def apply(%Table{} = table, %RoundCompleted{}) do
    table
  end
end
