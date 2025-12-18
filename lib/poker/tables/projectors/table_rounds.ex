defmodule Poker.Tables.Projectors.TableRounds do
  use Commanded.Projections.Ecto,
    application: Poker.App,
    repo: Poker.Repo,
    name: __MODULE__,
    consistency: :strong

  alias Poker.Tables.Events.{RoundStarted, ParticipantToActSelected, RoundCompleted}
  alias Poker.Tables.Projections.TableRounds

  import Ecto.Query

  def round_query(id), do: from(r in TableRounds, where: r.id == ^id)

  project(
    %RoundStarted{
      id: id,
      hand_id: hand_id,
      type: type,
      community_cards: community_cards,
      table_id: table_id
    },
    fn multi ->
      d = from(r in Poker.Tables.Projections.TableHands, where: r.table_id == ^table_id)

      dbg(Poker.Repo.all(d))
      dbg(hand_id)

      Ecto.Multi.insert(multi, :round, %TableRounds{
        id: id,
        hand_id: hand_id,
        round_type: type,
        community_cards: community_cards
      })
    end
  )

  project(%RoundCompleted{id: _id}, fn multi ->
    multi
  end)

  project(
    %ParticipantToActSelected{round_id: round_id, participant_id: participant_id},
    fn multi ->
      Ecto.Multi.update_all(
        multi,
        :round,
        round_query(round_id),
        set: [participant_to_act_id: participant_id]
      )
    end
  )

  @impl Commanded.Projections.Ecto
  def after_update(
        %RoundStarted{id: round_id, table_id: table_id, community_cards: community_cards},
        _metadata,
        _changes
      ) do
    Poker.TableEvents.broadcast_table(table_id, :round_started, %{
      id: round_id,
      community_cards: community_cards
    })
  end

  @impl Commanded.Projections.Ecto
  def after_update(
        %RoundCompleted{id: round_id, table_id: table_id},
        _metadata,
        _changes
      ) do
    Poker.TableEvents.broadcast_table(table_id, :round_finished, %{
      id: round_id
    })
  end

  def after_update(
        %ParticipantToActSelected{
          table_id: table_id,
          round_id: round_id,
          participant_id: participant_id
        },
        _metadata,
        _changes
      ) do
    Poker.TableEvents.broadcast_table(table_id, :participant_to_act_selected, %{
      round_id: round_id,
      participant_id: participant_id
    })
  end
end
