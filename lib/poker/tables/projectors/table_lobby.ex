defmodule Poker.Tables.Projectors.TableLobby do
  use Commanded.Projections.Ecto,
    application: Poker.App,
    repo: Poker.Repo,
    name: __MODULE__,
    consistency: :strong

  alias Poker.Tables.Events.{
    TableCreated,
    TableFinished,
    ParticipantJoined,
    ParticipantBusted,
    TableStarted
  }

  alias Poker.Tables.Projections.TableLobby

  def max_seats(:six_max), do: 6

  def table_query(id), do: from(t in TableLobby, where: t.id == ^id)

  project(
    %TableCreated{
      id: id,
      status: status,
      table_type: table_type,
      small_blind: small_blind,
      big_blind: big_blind,
      starting_stack: starting_stack,
      creator_id: creator_id
    },
    fn multi ->
      seats_count = max_seats(table_type)

      Ecto.Multi.insert(multi, :table, %TableLobby{
        id: id,
        small_blind: small_blind,
        big_blind: big_blind,
        starting_stack: starting_stack,
        table_type: table_type,
        seated_count: 0,
        seats_count: seats_count,
        status: status,
        creator_id: creator_id
      })
    end
  )

  project(%TableStarted{id: id, status: status}, fn multi ->
    Ecto.Multi.update_all(multi, :table, table_query(id), set: [status: status])
  end)

  project(%ParticipantJoined{table_id: id, player_id: player_id}, fn multi ->
    user = Poker.Accounts.get_user!(player_id)

    participant_data = %{
      player_id: player_id,
      email: user.email
    }

    multi
    |> Ecto.Multi.run(:get_table, fn repo, _changes ->
      case repo.get(TableLobby, id) do
        nil -> {:error, :table_not_found}
        table -> {:ok, table}
      end
    end)
    |> Ecto.Multi.update(:table, fn %{get_table: table} ->
      participants = table.participants ++ [participant_data]

      table
      |> Ecto.Changeset.change(%{
        participants: participants,
        seated_count: table.seated_count + 1
      })
    end)
  end)

  project(%ParticipantBusted{table_id: id}, fn multi ->
    Ecto.Multi.update_all(multi, :table, table_query(id), inc: [seated_count: -1])
  end)

  project(%TableFinished{table_id: id}, fn multi ->
    Ecto.Multi.update_all(multi, :table, table_query(id), set: [status: :finished])
  end)

  def after_update(%TableCreated{id: _table_id}, _metadata, _changes), do: :ok

  def after_update(%TableStarted{id: table_id}, _metadata, _changes) do
    Poker.TableEvents.broadcast_lobby(table_id, :table_started)
  end

  def after_update(
        %ParticipantJoined{table_id: table_id, id: participant_id},
        _metadata,
        _changes
      ) do
    Poker.TableEvents.broadcast_lobby(table_id, :participant_joined, %{
      participant_id: participant_id
    })
  end

  def after_update(
        %ParticipantBusted{table_id: table_id, participant_id: participant_id},
        _metadata,
        _changes
      ) do
    Poker.TableEvents.broadcast_lobby(table_id, :participant_busted, %{
      participant_id: participant_id
    })
  end

  def after_update(%TableFinished{table_id: table_id}, _metadata, _changes) do
    Poker.TableEvents.broadcast_lobby(table_id, :table_finished)
  end
end
