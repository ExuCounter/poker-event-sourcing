defmodule Poker.Tables.Projectors.TableParticipants do
  use Commanded.Projections.Ecto,
    application: Poker.App,
    repo: Poker.Repo,
    name: __MODULE__,
    consistency: :strong

  alias Poker.Tables.Events.{
    ParticipantJoined,
    ParticipantSatOut,
    ParticipantSatIn,
    ParticipantBusted,
    HandFinished
  }

  alias Poker.Tables.Projections.TableParticipants

  import Ecto.Query

  def participant_query(id), do: from(p in TableParticipants, where: p.id == ^id)

  project(
    %ParticipantJoined{
      id: id,
      table_id: table_id,
      player_id: player_id,
      chips: chips,
      status: status,
      is_sitting_out: is_sitting_out
    },
    fn multi ->
      Ecto.Multi.insert(multi, :participant, %TableParticipants{
        id: id,
        table_id: table_id,
        player_id: player_id,
        chips: chips,
        status: status,
        is_sitting_out: is_sitting_out
      })
    end
  )

  project(%ParticipantSatOut{participant_id: participant_id}, fn multi ->
    Ecto.Multi.update_all(multi, :participant, participant_query(participant_id),
      set: [is_sitting_out: true]
    )
  end)

  project(%ParticipantSatIn{participant_id: participant_id}, fn multi ->
    Ecto.Multi.update_all(multi, :participant, participant_query(participant_id),
      set: [is_sitting_out: false]
    )
  end)

  project(%ParticipantBusted{participant_id: participant_id}, fn multi ->
    Ecto.Multi.update_all(multi, :participant, participant_query(participant_id),
      set: [status: :busted]
    )
  end)

  project(%HandFinished{payouts: payouts}, fn multi ->
    Enum.reduce(payouts, multi, fn payout, acc_multi ->
      Ecto.Multi.update_all(
        acc_multi,
        "update_chips_#{payout.participant_id}_#{payout.pot_id}",
        participant_query(payout.participant_id),
        inc: [chips: payout.amount]
      )
    end)
  end)

  @impl Commanded.Projections.Ecto
  def after_update(
        %ParticipantJoined{table_id: table_id, id: participant_id},
        _metadata,
        _changes
      ) do
    Poker.TableEvents.broadcast_table(table_id, :participant_joined, %{participant_id: participant_id})
  end

  def after_update(
        %ParticipantSatOut{table_id: table_id, participant_id: participant_id},
        _metadata,
        _changes
      ) do
    Poker.TableEvents.broadcast_table(table_id, :participant_sat_out, %{participant_id: participant_id})
  end

  def after_update(
        %ParticipantSatIn{table_id: table_id, participant_id: participant_id},
        _metadata,
        _changes
      ) do
    Poker.TableEvents.broadcast_table(table_id, :participant_sat_in, %{participant_id: participant_id})
  end

  def after_update(
        %ParticipantBusted{table_id: table_id, participant_id: participant_id},
        _metadata,
        _changes
      ) do
    Poker.TableEvents.broadcast_table(table_id, :participant_busted, %{participant_id: participant_id})
  end

  def after_update(%HandFinished{table_id: table_id, hand_id: hand_id, payouts: payouts}, _metadata, _changes) do
    Poker.TableEvents.broadcast_table(table_id, :payouts_distributed, %{
      hand_id: hand_id,
      payouts:
        Enum.map(payouts, fn payout ->
          %{
            participant_id: payout.participant_id,
            pot_id: payout.pot_id,
            amount: payout.amount
          }
        end)
    })
  end
end
