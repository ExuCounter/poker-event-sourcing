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
    ParticipantLeft,
    TableStarted,
    TablePaused,
    TableResumed
  }

  alias Poker.Tables.Projections.TableLobby

  def max_seats(:two_max), do: 2
  def max_seats(:three_max), do: 3
  def max_seats(:four_max), do: 4
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
    _metadata,
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

  project(%TableStarted{id: id, status: status}, _metadata, fn multi ->
    Ecto.Multi.update_all(multi, :table, table_query(id), set: [status: status])
  end)

  project(%ParticipantJoined{id: participant_id, table_id: id, player_id: player_id, seat_number: seat_number}, _metadata, fn multi ->
    user = Poker.Accounts.get_user!(player_id)

    participant_data = %{
      participant_id: participant_id,
      player_id: player_id,
      email: user.email,
      nickname: user.nickname,
      seat_number: seat_number
    }

    multi
    |> Ecto.Multi.run(:get_table, fn _repo, _changes ->
      case Poker.Repo.get(TableLobby, id) do
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

  project(%ParticipantBusted{table_id: id, player_id: player_id}, _metadata, fn multi ->
    multi
    |> Ecto.Multi.run(:get_table, fn _repo, _changes ->
      case Poker.Repo.get(TableLobby, id) do
        nil -> {:error, :table_not_found}
        table -> {:ok, table}
      end
    end)
    |> Ecto.Multi.update(:table, fn %{get_table: table} ->
      updated_participants =
        Enum.map(table.participants, fn participant ->
          if participant.player_id == player_id do
            %{participant | status: :busted}
          else
            participant
          end
        end)

      table
      |> Ecto.Changeset.change(%{
        participants: updated_participants,
        seated_count: table.seated_count - 1
      })
    end)
  end)

  project(%ParticipantLeft{table_id: id, player_id: player_id}, _metadata, fn multi ->
    multi
    |> Ecto.Multi.run(:get_table, fn _repo, _changes ->
      case Poker.Repo.get(TableLobby, id) do
        nil -> {:error, :table_not_found}
        table -> {:ok, table}
      end
    end)
    |> Ecto.Multi.update(:table, fn %{get_table: table} ->
      updated_participants =
        Enum.reject(table.participants, fn participant ->
          participant.player_id == player_id
        end)

      table
      |> Ecto.Changeset.change(%{
        participants: updated_participants,
        seated_count: max(table.seated_count - 1, 0)
      })
    end)
  end)

  project(%TableFinished{table_id: id}, fn multi ->
    Ecto.Multi.update_all(multi, :table, table_query(id), set: [status: :finished])
  end)

  project(%TablePaused{table_id: id}, fn multi ->
    Ecto.Multi.update_all(multi, :table, table_query(id), set: [status: :paused])
  end)

  project(%TableResumed{table_id: id}, fn multi ->
    Ecto.Multi.update_all(multi, :table, table_query(id), set: [status: :live])
  end)

  def after_update(%TableCreated{id: _table_id}, _metadata, _changes), do: :ok

  def after_update(%TableStarted{id: table_id}, _metadata, _changes) do
    Poker.Tables.PubSub.broadcast_lobby(table_id, :table_started)
  end

  def after_update(
        %ParticipantJoined{table_id: table_id, id: participant_id},
        _metadata,
        _changes
      ) do
    Poker.Tables.PubSub.broadcast_lobby(table_id, :participant_joined, %{
      participant_id: participant_id
    })
  end

  def after_update(
        %ParticipantBusted{table_id: table_id, participant_id: participant_id},
        _metadata,
        _changes
      ) do
    Poker.Tables.PubSub.broadcast_lobby(table_id, :participant_busted, %{
      participant_id: participant_id
    })
  end

  def after_update(
        %ParticipantLeft{table_id: table_id, participant_id: participant_id},
        _metadata,
        _changes
      ) do
    Poker.Tables.PubSub.broadcast_lobby(table_id, :participant_left, %{
      participant_id: participant_id
    })
  end

  def after_update(%TableFinished{table_id: table_id}, _metadata, _changes) do
    Poker.Tables.PubSub.broadcast_lobby(table_id, :table_finished)
  end

  def after_update(%TablePaused{table_id: table_id}, _metadata, _changes) do
    Poker.Tables.PubSub.broadcast_lobby(table_id, :table_paused)
  end

  def after_update(%TableResumed{table_id: table_id}, _metadata, _changes) do
    Poker.Tables.PubSub.broadcast_lobby(table_id, :table_resumed)
  end
end
