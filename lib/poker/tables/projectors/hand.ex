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

  def after_update(
        %Poker.Tables.Events.HandStarted{table_id: table_id} = event,
        _metadata,
        _changes
      ) do
    {:ok, table} = Poker.Repo.find_by_id(Poker.Tables.Projections.Table, table_id)

    Phoenix.PubSub.broadcast(Poker.PubSub, "table:#{table.id}", {:hand_started, event})

    :ok
  end
end
