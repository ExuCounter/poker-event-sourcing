defmodule Poker.Tables.Projectors.TableState do
  use Commanded.Projections.Ecto,
    application: Poker.App,
    repo: Poker.Repo,
    name: __MODULE__,
    consistency: :strong

  alias Poker.Tables.Events.{
    HandStarted,
    HandFinished,
    ParticipantHandGiven,
    RoundStarted,
    ParticipantActedInHand,
    ParticipantToActSelected,
    PotsRecalculated,
    TableStarted
  }

  alias Poker.Tables.Projections.{TableState, TableLobby}

  import Ecto.Query

  def table_state_query(table_id), do: from(t in TableState, where: t.id == ^table_id)

  project(%TableStarted{id: table_id}, fn multi ->
    Ecto.Multi.insert(multi, :table_state, %TableState{id: table_id})
  end)

  project(%HandStarted{id: hand_id, table_id: table_id}, fn multi ->
    Ecto.Multi.update_all(multi, :table, table_state_query(table_id), set: [hand_id: hand_id])
  end)

  # project(
  #   %ParticipantHandGiven{
  #     table_id: table_id,
  #     participant_id: participant_id,
  #     hole_cards: hole_cards,
  #     position: position,
  #     status: status
  #   },
  #   fn multi ->
  #     # Get aggregate to find seat_number
  #     import Ecto.Query

  #     seat_number =
  #       case Poker.Repo.one(
  #              from(e in "streams",
  #                where:
  #                  e.stream_uuid == ^table_id and
  #                    fragment("(data->>'participant_id')::uuid = ?", ^participant_id) and
  #                    e.event_type == "Elixir.Poker.Tables.Events.ParticipantJoined",
  #                select: fragment("(data->>'seat_number')::integer"),
  #                limit: 1
  #              )
  #            ) do
  #         nil -> 1
  #         num -> num
  #       end

  #     participant_hand = %{
  #       participant_id: participant_id,
  #       seat_number: seat_number,
  #       hole_cards: hole_cards,
  #       position: position,
  #       status: status
  #     }

  #     multi
  #     |> Ecto.Multi.run(:get_table_state, fn repo, _changes ->
  #       case repo.one(table_state_query(table_id)) do
  #         nil -> {:error, :table_state_not_found}
  #         table_state -> {:ok, table_state}
  #       end
  #     end)
  #     |> Ecto.Multi.update(:table_state, fn %{get_table_state: table_state} ->
  #       participant_hands = table_state.participant_hands ++ [participant_hand]

  #       table_state
  #       |> Ecto.Changeset.change(%{
  #         participant_hands: participant_hands
  #       })
  #     end)
  #   end
  # )

  # project(
  #   %RoundStarted{
  #     hand_id: hand_id,
  #     type: type,
  #     community_cards: community_cards
  #   },
  #   fn multi ->
  #     # Find table_state by querying for the hand
  #     multi
  #     |> Ecto.Multi.run(:find_table_state, fn repo, _changes ->
  #       query = from(t in TableState, where: fragment("? IS NOT NULL", t.round_type) == false)
  #       # For now, we'll just update all table_states - in production you'd track hand_id
  #       case repo.all(query) do
  #         [] -> {:error, :no_active_table_state}
  #         states -> {:ok, states}
  #       end
  #     end)
  #     |> Ecto.Multi.run(:update_round, fn repo, %{find_table_state: states} ->
  #       # Just take the first one for simplicity
  #       # In production, you'd need to track which table_state corresponds to this hand
  #       table_state = List.first(states)

  #       if table_state do
  #         updated_community_cards = table_state.community_cards ++ community_cards

  #         # Reset bet_this_round for all participant_hands
  #         updated_participant_hands =
  #           Enum.map(table_state.participant_hands, fn hand ->
  #             # Keep existing fields but this is just for the projection
  #             hand
  #           end)

  #         changeset =
  #           table_state
  #           |> Ecto.Changeset.change(%{
  #             round_type: type,
  #             community_cards: updated_community_cards,
  #             participant_hands: updated_participant_hands
  #           })

  #         repo.update(changeset)
  #       else
  #         {:error, :table_state_not_found}
  #       end
  #     end)
  #   end
  # )

  # project(
  #   %ParticipantActedInHand{
  #     table_hand_id: hand_id,
  #     participant_id: participant_id,
  #     action: action
  #   },
  #   fn multi ->
  #     # Find and update participant_hand status based on action
  #     multi
  #     |> Ecto.Multi.run(:update_participant_status, fn repo, _changes ->
  #       # For now just find any table_state - in production track by hand_id properly
  #       query = from(t in TableState, limit: 1)

  #       case repo.one(query) do
  #         nil ->
  #           {:error, :table_state_not_found}

  #         table_state ->
  #           updated_participant_hands =
  #             Enum.map(table_state.participant_hands, fn hand ->
  #               if hand.participant_id == participant_id do
  #                 new_status =
  #                   case action do
  #                     :fold -> :folded
  #                     :all_in -> :all_in
  #                     _ -> hand.status
  #                   end

  #                 %{hand | status: new_status}
  #               else
  #                 hand
  #               end
  #             end)

  #           changeset =
  #             table_state
  #             |> Ecto.Changeset.change(%{
  #               participant_hands: updated_participant_hands
  #             })

  #           repo.update(changeset)
  #       end
  #     end)
  #   end
  # )

  # project(
  #   %ParticipantToActSelected{table_id: table_id, participant_id: participant_id},
  #   fn multi ->
  #     query = table_state_query(table_id)

  #     Ecto.Multi.update_all(multi, :table_state, query,
  #       set: [participant_to_act_id: participant_id]
  #     )
  #   end
  # )

  # project(%PotsRecalculated{table_id: table_id, pots: pots}, fn multi ->
  #   pots_data = Enum.map(pots, fn pot -> %{amount: pot.amount} end)

  #   query = table_state_query(table_id)

  #   Ecto.Multi.update_all(multi, :table_state, query, set: [pots: pots_data])
  # end)

  # project(%HandFinished{table_id: table_id}, fn multi ->
  #   query = table_state_query(table_id)
  #   Ecto.Multi.delete_all(multi, :table_state, query)
  # end)

  @impl Commanded.Projections.Ecto
  def after_update(%TableStarted{id: table_id}, _metadata, _changes) do
    Phoenix.PubSub.broadcast(Poker.PubSub, "table:#{table_id}:game", :game_updated)
    :ok
  end

  @impl Commanded.Projections.Ecto
  def after_update(%HandStarted{table_id: table_id}, _metadata, _changes) do
    Phoenix.PubSub.broadcast(Poker.PubSub, "table:#{table_id}:game", :game_updated)
    :ok
  end

  def after_update(%ParticipantHandGiven{table_id: table_id}, _metadata, _changes) do
    Phoenix.PubSub.broadcast(Poker.PubSub, "table:#{table_id}:game", :game_updated)
    :ok
  end

  def after_update(%RoundStarted{}, _metadata, _changes) do
    # Broadcast to all active games - ideally we'd have table_id here
    :ok
  end

  def after_update(%ParticipantActedInHand{}, _metadata, _changes) do
    :ok
  end

  def after_update(%ParticipantToActSelected{table_id: table_id}, _metadata, _changes) do
    Phoenix.PubSub.broadcast(Poker.PubSub, "table:#{table_id}:game", :game_updated)
    :ok
  end

  def after_update(%PotsRecalculated{table_id: table_id}, _metadata, _changes) do
    Phoenix.PubSub.broadcast(Poker.PubSub, "table:#{table_id}:game", :game_updated)
    :ok
  end

  def after_update(%HandFinished{table_id: table_id}, _metadata, _changes) do
    Phoenix.PubSub.broadcast(Poker.PubSub, "table:#{table_id}:game", :game_updated)
    :ok
  end

  def after_update(_event, _metadata, _changes), do: :ok
end
