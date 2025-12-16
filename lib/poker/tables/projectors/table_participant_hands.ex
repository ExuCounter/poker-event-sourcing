defmodule Poker.Tables.Projectors.TableParticipantHands do
  use Commanded.Projections.Ecto,
    application: Poker.App,
    repo: Poker.Repo,
    name: __MODULE__,
    consistency: :strong

  alias Poker.Tables.Events.{ParticipantHandGiven, ParticipantActedInHand}
  alias Poker.Tables.Projections.TableParticipantHands

  import Ecto.Query

  def participant_hand_query(id), do: from(ph in TableParticipantHands, where: ph.id == ^id)

  project(
    %ParticipantHandGiven{
      id: id,
      table_hand_id: hand_id,
      participant_id: participant_id,
      hole_cards: hole_cards,
      position: position,
      status: status
    },
    fn multi ->
      Ecto.Multi.insert(multi, :participant_hand, %TableParticipantHands{
        id: id,
        hand_id: hand_id,
        participant_id: participant_id,
        hole_cards: hole_cards,
        position: position,
        status: status
      })
    end
  )

  project(%ParticipantActedInHand{id: participant_hand_id, action: action}, fn multi ->
    status =
      case action do
        :fold -> :folded
        :all_in -> :all_in
        _ -> :playing
      end

    Ecto.Multi.update_all(
      multi,
      :participant_hand,
      participant_hand_query(participant_hand_id),
      set: [status: status]
    )
  end)

  @impl Commanded.Projections.Ecto
  def after_update(
        %ParticipantHandGiven{
          id: participant_hand_id,
          participant_id: participant_id,
          table_id: table_id,
          hole_cards: hole_cards,
          position: position,
          status: status
        },
        _metadata,
        _changes
      ) do
    Phoenix.PubSub.broadcast(
      Poker.PubSub,
      "table:#{table_id}:participant_hands",
      {:participant_hand_given,
       %{
         id: participant_hand_id,
         participant_id: participant_id,
         hole_cards: hole_cards,
         position: position,
         status: status
       }}
    )

    :ok
  end

  def after_update(
        %ParticipantActedInHand{
          id: participant_hand_id,
          participant_id: participant_id,
          table_id: table_id,
          action: action
        },
        _metadata,
        _changes
      ) do
    status =
      case action do
        :fold -> :folded
        :all_in -> :all_in
        _ -> :active
      end

    Phoenix.PubSub.broadcast(
      Poker.PubSub,
      "table:#{table_id}:participant_hands",
      {:participant_acted,
       %{
         id: participant_hand_id,
         participant_id: participant_id,
         action: action,
         status: status
       }}
    )

    :ok
  end
end
