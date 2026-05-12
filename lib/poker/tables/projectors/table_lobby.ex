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

  def table_query(id), do: from(table_lobby in TableLobby, where: table_lobby.id == ^id)

  project(
    %TableCreated{
      id: id,
      status: status,
      table_type: table_type,
      game_mode: game_mode,
      source_id: source_id
    },
    _metadata,
    fn multi ->
      Ecto.Multi.insert(multi, :table, %TableLobby{
        id: id,
        seated_count: 0,
        seats_count: max_seats(table_type),
        status: status,
        game_mode: game_mode,
        source_id: source_id
      })
    end
  )

  project(%TableStarted{id: id, status: status}, _metadata, fn multi ->
    Ecto.Multi.update_all(multi, :table, table_query(id), set: [status: status])
  end)

  project(
    %ParticipantJoined{
      id: participant_id,
      table_id: id,
      player_id: player_id,
      seat_number: seat_number
    },
    _metadata,
    fn multi ->
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
        table
        |> Ecto.Changeset.change(%{
          participants: table.participants ++ [participant_data],
          seated_count: table.seated_count + 1
        })
      end)
    end
  )

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

  # Broadcast to the per-table lobby topic and the appropriate list topic after each commit.
  def after_update(%TableCreated{id: table_id, game_mode: game_mode} = event, _metadata, _changes) do
    Poker.Tables.PubSub.broadcast_lobby(table_id, event_type(event))
    broadcast_list(game_mode)
    :ok
  end

  def after_update(event, _metadata, changes) do
    table_id = table_id_for(event)
    Poker.Tables.PubSub.broadcast_lobby(table_id, event_type(event))

    game_mode = game_mode_from_changes(changes) || lookup_game_mode(table_id)
    broadcast_list(game_mode)
    :ok
  end

  defp table_id_for(%{table_id: table_id}), do: table_id
  defp table_id_for(%{id: id}), do: id

  defp game_mode_from_changes(%{table: %TableLobby{game_mode: game_mode}}), do: game_mode
  defp game_mode_from_changes(_), do: nil

  defp lookup_game_mode(table_id) do
    case Poker.Repo.get(TableLobby, table_id) do
      %TableLobby{game_mode: game_mode} -> game_mode
      nil -> nil
    end
  end

  defp broadcast_list(:cash_game) do
    Poker.CashGames.PubSub.broadcast_cash_games_list(:updated)
  end

  defp broadcast_list(:tournament) do
    Poker.Tournaments.PubSub.broadcast_tournament_list(:updated)
  end

  defp broadcast_list(_), do: :ok

  defp event_type(event) do
    event.__struct__
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
    |> String.to_atom()
  end
end
