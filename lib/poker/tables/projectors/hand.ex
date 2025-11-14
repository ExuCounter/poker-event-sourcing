defmodule Poker.Tables.Projectors.Hand do
  use Commanded.Projections.Ecto,
    name: "Tables.Projectors.Hand",
    repo: Poker.Repo,
    application: Poker.App,
    consistency: :strong

  def split_community_cards_by_rounds(community_cards) do
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

  project(%Poker.Tables.Events.RoundStarted{} = started, fn multi ->
    Ecto.Multi.update_all(
      multi,
      :update_participant_to_act,
      fn _ ->
        from(h in Poker.Tables.Projections.Hand,
          where: h.id == ^started.hand_id
        )
      end,
      set: [participant_to_act_id: started.participant_to_act_id]
    )
  end)

  project(%Poker.Tables.Events.ParticipantActedInHand{} = acted, fn multi ->
    Ecto.Multi.update_all(
      multi,
      :update_participant_to_act,
      fn _ ->
        from(h in Poker.Tables.Projections.Hand,
          where: h.id == ^acted.table_hand_id
        )
      end,
      set: [participant_to_act_id: acted.next_participant_to_act_id]
    )
  end)

  # def after_update(
  #       %Poker.Tables.Events.HandStarted{table_id: table_id} = event,
  #       _metadata,
  #       _changes
  #     ) do
  #   {:ok, table} = Poker.Repo.find_by_id(Poker.Tables.Projections.Table, table_id)

  #   Phoenix.PubSub.broadcast(Poker.PubSub, "table:#{table.id}", {:hand_started, event})

  #   :ok
  # end
end
