defmodule Poker.Tables.Projectors.TableParticipantHands do
  use Commanded.Projections.Ecto,
    application: Poker.App,
    repo: Poker.Repo,
    name: __MODULE__,
    consistency: :strong

  alias Poker.Tables.Events.{
    ParticipantHandGiven,
    ParticipantFolded,
    ParticipantChecked,
    ParticipantCalled,
    ParticipantRaised,
    ParticipantWentAllIn,
    SmallBlindPosted,
    BigBlindPosted,
    RoundCompleted
  }

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
      status: status,
      bet_this_round: bet_this_round
    },
    fn multi ->
      Ecto.Multi.insert(multi, :participant_hand, %TableParticipantHands{
        id: id,
        hand_id: hand_id,
        participant_id: participant_id,
        hole_cards: hole_cards,
        position: position,
        status: status,
        bet_this_round: bet_this_round
      })
    end
  )

  project(%ParticipantFolded{id: participant_hand_id, status: status}, fn multi ->
    Ecto.Multi.update_all(
      multi,
      :participant_hand,
      participant_hand_query(participant_hand_id),
      set: [status: status]
    )
  end)

  project(%ParticipantChecked{id: participant_hand_id, status: status}, fn multi ->
    Ecto.Multi.update_all(
      multi,
      :participant_hand,
      participant_hand_query(participant_hand_id),
      set: [status: status]
    )
  end)

  project(
    %ParticipantCalled{id: participant_hand_id, status: status, amount: amount},
    fn multi ->
      Ecto.Multi.update_all(
        multi,
        :participant_hand,
        participant_hand_query(participant_hand_id),
        set: [status: status],
        inc: [bet_this_round: +amount]
      )
    end
  )

  project(%ParticipantRaised{id: participant_hand_id, status: status, amount: amount}, fn multi ->
    dbg(participant_hand_query(participant_hand_id) |> Poker.Repo.all())
    dbg(amount)

    Ecto.Multi.update_all(
      multi,
      :participant_hand,
      participant_hand_query(participant_hand_id),
      set: [status: status],
      inc: [bet_this_round: +amount]
    )
  end)

  project(
    %ParticipantWentAllIn{id: participant_hand_id, status: status, amount: amount},
    fn multi ->
      Ecto.Multi.update_all(
        multi,
        :participant_hand,
        participant_hand_query(participant_hand_id),
        set: [status: status],
        inc: [bet_this_round: +amount]
      )
    end
  )

  project(
    %RoundCompleted{hand_id: hand_id},
    fn multi ->
      Ecto.Multi.update_all(
        multi,
        :participant_hands,
        from(ph in TableParticipantHands, where: ph.hand_id == ^hand_id),
        set: [bet_this_round: 0]
      )
    end
  )

  project(
    %SmallBlindPosted{participant_hand_id: participant_hand_id, amount: amount},
    fn multi ->
      Ecto.Multi.update_all(
        multi,
        :participant_hand,
        participant_hand_query(participant_hand_id),
        inc: [bet_this_round: +amount]
      )
    end
  )

  project(
    %BigBlindPosted{participant_hand_id: participant_hand_id, amount: amount},
    fn multi ->
      Ecto.Multi.update_all(
        multi,
        :participant_hand,
        participant_hand_query(participant_hand_id),
        inc: [bet_this_round: +amount]
      )
    end
  )

  @impl Commanded.Projections.Ecto
  def after_update(
        %ParticipantHandGiven{
          id: participant_hand_id,
          participant_id: participant_id,
          table_id: table_id,
          hole_cards: hole_cards,
          position: position,
          status: status,
          bet_this_round: 0
        },
        _metadata,
        _changes
      ) do
    Poker.TableEvents.broadcast_table(
      table_id,
      :participant_hand_given,
      %{
        id: participant_hand_id,
        participant_id: participant_id,
        hole_cards: hole_cards,
        position: position,
        status: status,
        bet_this_round: 0
      }
    )
  end

  def after_update(
        %ParticipantFolded{
          id: participant_hand_id,
          participant_id: participant_id,
          table_id: table_id,
          status: status
        },
        _metadata,
        _changes
      ) do
    Poker.TableEvents.broadcast_table(
      table_id,
      :participant_folded,
      %{
        id: participant_hand_id,
        participant_id: participant_id,
        status: status
      }
    )
  end

  def after_update(
        %ParticipantChecked{
          id: participant_hand_id,
          participant_id: participant_id,
          table_id: table_id
        },
        _metadata,
        _changes
      ) do
    Poker.TableEvents.broadcast_table(
      table_id,
      :participant_checked,
      %{
        id: participant_hand_id,
        participant_id: participant_id
      }
    )
  end

  def after_update(
        %ParticipantCalled{
          id: participant_hand_id,
          participant_id: participant_id,
          table_id: table_id,
          amount: amount
        },
        _metadata,
        _changes
      ) do
    Poker.TableEvents.broadcast_table(
      table_id,
      :participant_called,
      %{
        id: participant_hand_id,
        participant_id: participant_id,
        amount: amount
      }
    )
  end

  def after_update(
        %ParticipantRaised{
          id: participant_hand_id,
          participant_id: participant_id,
          table_id: table_id,
          amount: amount
        },
        _metadata,
        _changes
      ) do
    Poker.TableEvents.broadcast_table(
      table_id,
      :participant_raised,
      %{
        id: participant_hand_id,
        participant_id: participant_id,
        amount: amount
      }
    )
  end

  def after_update(
        %ParticipantWentAllIn{
          id: participant_hand_id,
          participant_id: participant_id,
          table_id: table_id,
          status: status,
          amount: amount
        },
        _metadata,
        _changes
      ) do
    Poker.TableEvents.broadcast_table(
      table_id,
      :participant_went_all_in,
      %{
        id: participant_hand_id,
        participant_id: participant_id,
        status: status,
        amount: amount
      }
    )
  end

  def after_update(_event, _metadata, _changes) do
    :ok
  end
end
