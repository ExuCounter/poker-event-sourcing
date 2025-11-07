defmodule Poker.Tables.Projectors.Hand do
  use Commanded.Projections.Ecto,
    name: "Tables.Projectors.Hand",
    repo: Poker.Repo,
    application: Poker.App,
    consistency: :strong

  def split_community_cards_by_rounds(community_cards) when is_list(community_cards) do
    [first_flop_card, second_flop_card, third_flop_card, turn_card, river_card] = community_cards

    %{
      flop_cards: [first_flop_card, second_flop_card, third_flop_card],
      turn_card: turn_card,
      river_card: river_card
    }
  end

  project(%Poker.Tables.Events.HandStarted{} = started, fn multi ->
    Ecto.Multi.insert(
      multi,
      :hand,
      %Poker.Tables.Projections.Hand{
        id: started.id,
        table_id: started.table_id,
        dealer_button_id: started.dealer_button_id,
        flop_cards: [],
        turn_card: nil,
        river_card: nil
      }
    )
  end)
end
