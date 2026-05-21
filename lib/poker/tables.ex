defmodule Poker.Tables do
  @moduledoc """
  Tables context - public API for poker table operations.

  This module provides the main interface for interacting with poker tables.
  It dispatches commands to the event-sourced aggregate and queries projections.

  ## Architecture

  Tables uses Event Sourcing via Commanded:
  - Commands are validated and dispatched to aggregates
  - Events are stored and projected to read models
  - Process managers orchestrate workflows (hand progression, timeouts)

  ## Example Usage

      # Create a new table
      {:ok, %{table_id: id}} = Tables.create_table(user_id, %{small_blind: 10})

      # Join a table
      {:ok, participant_id} = Tables.join_participant(table_id, player_id)

      # Player actions
      :ok = Tables.fold_hand(table_id, player_id)
      :ok = Tables.call_hand(table_id, player_id)
      :ok = Tables.raise_hand(table_id, player_id, 100)
  """

  alias Poker.Tables.Commands.{
    CreateTable,
    JoinTableParticipant,
    StartTable,
    ParticipantFold,
    ParticipantCheck,
    ParticipantCall,
    ParticipantRaise,
    ParticipantAllIn,
    SitOutParticipant,
    SitInParticipant,
    BuyInParticipant,
    TimeoutParticipant,
    LeaveTable,
    UpdateTableBlinds
  }

  import Ecto.Query

  def create_table(creator_id, settings_attrs \\ %{}) do
    table_id = UUIDv7.generate()
    creator_participant_id = UUIDv7.generate()
    settings_id = UUIDv7.generate()

    Poker.Telemetry.span_command(
      :create_table,
      %{
        table_id: table_id,
        creator_id: creator_id
      },
      fn ->
        command_attrs = %{
          table_id: table_id,
          creator_id: creator_id,
          creator_participant_id: creator_participant_id,
          settings_id: settings_id,
          settings: settings_attrs
        }

        with {:ok, command} <-
               Poker.Repo.validate_changeset(command_attrs, &CreateTable.changeset/1),
             :ok <- Poker.App.dispatch(command, consistency: :strong) do
          {:ok,
           %{
             table_id: table_id,
             creator_participant_id: creator_participant_id,
             settings_id: settings_id
           }}
        end
      end
    )
  end

  def join_participant(table_id, player_id, %{seat_number: nil} = attrs) do
    lobby = get_lobby(table_id)
    occupied_seats = Enum.map(lobby.participants, & &1.seat_number)

    case Enum.find(1..lobby.seats_count, fn seat -> seat not in occupied_seats end) do
      nil -> {:error, %{message: "No seats available"}}
      seat_number -> join_participant(table_id, player_id, %{attrs | seat_number: seat_number})
    end
  end

  def join_participant(table_id, player_id, attrs \\ %{}) do
    participant_id = UUIDv7.generate()
    starting_stack = Map.get(attrs, :starting_stack)
    nickname = Map.get(attrs, :nickname)
    seat_number = Map.get(attrs, :seat_number)

    Poker.Telemetry.span_command(
      :join,
      %{
        table_id: table_id,
        player_id: player_id,
        participant_id: participant_id
      },
      fn ->
        command_attrs = %{
          participant_id: participant_id,
          player_id: player_id,
          table_id: table_id,
          starting_stack: starting_stack,
          nickname: nickname,
          seat_number: seat_number
        }

        with {:ok, command} <-
               Poker.Repo.validate_changeset(command_attrs, &JoinTableParticipant.changeset/1),
             :ok <- Poker.App.dispatch(command, consistency: :strong) do
          {:ok, participant_id}
        end
      end
    )
  end

  def start_table(table_id) do
    Poker.Telemetry.span_command(:start_table, %{table_id: table_id}, fn ->
      command_attrs = %{table_id: table_id}

      with {:ok, command} <- Poker.Repo.validate_changeset(command_attrs, &StartTable.changeset/1),
           :ok <- Poker.App.dispatch(command) do
        :ok
      end
    end)
  end

  def fold_hand(table_id, player_id) do
    hand_action_id = UUIDv7.generate()

    Poker.Telemetry.span_command(
      :fold,
      %{
        table_id: table_id,
        player_id: player_id,
        hand_action_id: hand_action_id
      },
      fn ->
        command_attrs = %{
          hand_action_id: hand_action_id,
          player_id: player_id,
          table_id: table_id
        }

        with {:ok, command} <-
               Poker.Repo.validate_changeset(command_attrs, &ParticipantFold.changeset/1),
             :ok <- Poker.App.dispatch(command) do
          :ok
        end
      end
    )
  end

  def check_hand(table_id, player_id) do
    hand_action_id = UUIDv7.generate()

    Poker.Telemetry.span_command(
      :check,
      %{
        table_id: table_id,
        player_id: player_id,
        hand_action_id: hand_action_id
      },
      fn ->
        command_attrs = %{
          hand_action_id: hand_action_id,
          player_id: player_id,
          table_id: table_id
        }

        with {:ok, command} <-
               Poker.Repo.validate_changeset(command_attrs, &ParticipantCheck.changeset/1),
             :ok <- Poker.App.dispatch(command) do
          :ok
        end
      end
    )
  end

  def call_hand(table_id, player_id) do
    hand_action_id = UUIDv7.generate()

    Poker.Telemetry.span_command(
      :call,
      %{
        table_id: table_id,
        player_id: player_id,
        hand_action_id: hand_action_id
      },
      fn ->
        command_attrs = %{
          hand_action_id: hand_action_id,
          player_id: player_id,
          table_id: table_id
        }

        with {:ok, command} <-
               Poker.Repo.validate_changeset(command_attrs, &ParticipantCall.changeset/1),
             :ok <- Poker.App.dispatch(command) do
          :ok
        end
      end
    )
  end

  def raise_hand(table_id, player_id, amount) do
    hand_action_id = UUIDv7.generate()

    Poker.Telemetry.span_command(
      :raise,
      %{
        table_id: table_id,
        player_id: player_id,
        hand_action_id: hand_action_id,
        amount: amount
      },
      fn ->
        command_attrs = %{
          hand_action_id: hand_action_id,
          player_id: player_id,
          table_id: table_id,
          amount: amount
        }

        with {:ok, command} <-
               Poker.Repo.validate_changeset(command_attrs, &ParticipantRaise.changeset/1),
             :ok <- Poker.App.dispatch(command) do
          :ok
        end
      end
    )
  end

  def all_in_hand(table_id, player_id) do
    hand_action_id = UUIDv7.generate()

    Poker.Telemetry.span_command(
      :all_in,
      %{
        table_id: table_id,
        player_id: player_id,
        hand_action_id: hand_action_id
      },
      fn ->
        command_attrs = %{
          hand_action_id: hand_action_id,
          player_id: player_id,
          table_id: table_id
        }

        with {:ok, command} <-
               Poker.Repo.validate_changeset(command_attrs, &ParticipantAllIn.changeset/1),
             :ok <- Poker.App.dispatch(command) do
          :ok
        end
      end
    )
  end

  def sit_out_participant(table_id, player_id) do
    Poker.Telemetry.span_command(
      :sit_out,
      %{
        table_id: table_id,
        player_id: player_id
      },
      fn ->
        command_attrs = %{
          player_id: player_id,
          table_id: table_id
        }

        with {:ok, command} <-
               Poker.Repo.validate_changeset(command_attrs, &SitOutParticipant.changeset/1),
             :ok <- Poker.App.dispatch(command) do
          :ok
        end
      end
    )
  end

  def sit_in_participant(table_id, player_id) do
    Poker.Telemetry.span_command(
      :sit_in,
      %{
        table_id: table_id,
        player_id: player_id
      },
      fn ->
        command_attrs = %{
          player_id: player_id,
          table_id: table_id
        }

        with {:ok, command} <-
               Poker.Repo.validate_changeset(command_attrs, &SitInParticipant.changeset/1),
             :ok <- Poker.App.dispatch(command) do
          :ok
        end
      end
    )
  end

  def buy_in_participant(table_id, player_id, amount) do
    Poker.Telemetry.span_command(
      :buy_in,
      %{
        table_id: table_id,
        player_id: player_id,
        amount: amount
      },
      fn ->
        command_attrs = %{
          player_id: player_id,
          table_id: table_id,
          amount: amount
        }

        with {:ok, command} <-
               Poker.Repo.validate_changeset(command_attrs, &BuyInParticipant.changeset/1),
             :ok <- Poker.App.dispatch(command, consistency: :strong) do
          :ok
        end
      end
    )
  end

  def leave_table(table_id, player_id) do
    Poker.Telemetry.span_command(
      :leave,
      %{
        table_id: table_id,
        player_id: player_id
      },
      fn ->
        command_attrs = %{
          player_id: player_id,
          table_id: table_id
        }

        with {:ok, command} <-
               Poker.Repo.validate_changeset(command_attrs, &LeaveTable.changeset/1),
             :ok <- Poker.App.dispatch(command, consistency: :strong) do
          :ok
        end
      end
    )
  end

  def update_table_blinds(table_id, small_blind, big_blind) do
    Poker.Telemetry.span_command(
      :update_blinds,
      %{
        table_id: table_id,
        small_blind: small_blind,
        big_blind: big_blind
      },
      fn ->
        command_attrs = %{
          table_id: table_id,
          small_blind: small_blind,
          big_blind: big_blind
        }

        with {:ok, command} <-
               Poker.Repo.validate_changeset(command_attrs, &UpdateTableBlinds.changeset/1),
             :ok <- Poker.App.dispatch(command, consistency: :strong) do
          :ok
        end
      end
    )
  end

  def timeout_participant(attrs) do
    Poker.Telemetry.span_command(
      :timeout,
      %{
        table_id: Map.get(attrs, :table_id),
        player_id: Map.get(attrs, :player_id)
      },
      fn ->
        with {:ok, command} <-
               Poker.Repo.validate_changeset(attrs, &TimeoutParticipant.changeset/1),
             :ok <- Poker.App.dispatch(command, consistency: :strong) do
          :ok
        end
      end
    )
  end

  def get_tables() do
    Poker.Tables.Projections.TableLobby
    |> order_by(desc: :inserted_at)
    |> Poker.Repo.all()
  end

  def get_lobby(table_id) do
    Poker.Repo.get(Poker.Tables.Projections.TableLobby, table_id)
  end

  def get_table_round(round_id) do
    Poker.Repo.get(Poker.Tables.Projections.TableRounds, round_id)
  end

  def list_tables() do
    Poker.Repo.all(Poker.Tables.Projections.TableLobby)
  end

  @doc """
  Get player-specific game view with all calculated state.
  Use this instead of get_table for game UI.

  Parameters:
    - table_id: The table UUID
    - player_id: The player UUID
    - since_version: Optional stream version of last processed event (nil for full replay)
  """
  def get_player_game_view(table_id, player_id, opts \\ []) do
    Poker.Tables.Views.PlayerGameView.build(table_id, player_id, opts)
  end
end
