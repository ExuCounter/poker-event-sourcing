defmodule Poker.Tables.Projectors.Table do
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
    TableStarted,
    RoundStarted
  }

  # alias Poker.Tables.Projections.{Table, TableLobby}

  # import Ecto.Query

  # def table_state_query(table_id), do: from(t in TableState, where: t.id == ^table_id)

  # project(%TableStarted{id: table_id}, fn multi ->
  #   Ecto.Multi.insert(multi, :table_state, %TableState{id: table_id})
  # end)

  # project(%HandStarted{id: hand_id, table_id: table_id}, fn multi ->
  #   Ecto.Multi.update_all(multi, :table, table_state_query(table_id), set: [hand_id: hand_id])
  # end)

  # project(%RoundStarted{table_id: table_id, type: type}, fn multi ->
  #   Ecto.Multi.update_all(multi, :table, table_state_query(table_id), set: [round_type: type])
  # end)
end
