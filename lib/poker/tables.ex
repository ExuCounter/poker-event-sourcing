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
    TimeoutParticipant,
    LeaveTable
  }

  import Ecto.Query

  def create_table(creator_id, settings_attrs \\ %{}) do
    table_id = UUIDv7.generate()
    creator_participant_id = UUIDv7.generate()
    settings_id = UUIDv7.generate()

    command_attrs = %{
      table_id: table_id,
      creator_id: creator_id,
      creator_participant_id: creator_participant_id,
      settings_id: settings_id,
      settings: settings_attrs
    }

    with {:ok, command} <- Poker.Repo.validate_changeset(command_attrs, &CreateTable.changeset/1),
         :ok <- Poker.App.dispatch(command, consistency: :strong) do
      {:ok,
       %{
         table_id: table_id,
         creator_participant_id: creator_participant_id,
         settings_id: settings_id
       }}
    end
  end

  def join_participant(table_id, player_id, attrs \\ %{}) do
    participant_id = UUIDv7.generate()
    starting_stack = Map.get(attrs, :starting_stack)
    nickname = Map.get(attrs, :nickname)

    command_attrs = %{
      participant_id: participant_id,
      player_id: player_id,
      table_id: table_id,
      starting_stack: starting_stack,
      nickname: nickname
    }

    with {:ok, command} <-
           Poker.Repo.validate_changeset(command_attrs, &JoinTableParticipant.changeset/1),
         :ok <- Poker.App.dispatch(command, consistency: :strong) do
      {:ok, participant_id}
    end
  end

  def start_table(table_id) do
    command_attrs = %{
      table_id: table_id
    }

    with {:ok, command} <- Poker.Repo.validate_changeset(command_attrs, &StartTable.changeset/1),
         :ok <- Poker.App.dispatch(command) do
      :ok
    end
  end

  def fold_hand(table_id, player_id) do
    hand_action_id = UUIDv7.generate()

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

  def check_hand(table_id, player_id) do
    hand_action_id = UUIDv7.generate()

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

  def call_hand(table_id, player_id) do
    hand_action_id = UUIDv7.generate()

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

  def raise_hand(table_id, player_id, amount) do
    hand_action_id = UUIDv7.generate()

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

  def all_in_hand(table_id, player_id) do
    hand_action_id = UUIDv7.generate()

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

  def sit_out_participant(table_id, player_id) do
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

  def sit_in_participant(table_id, player_id) do
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

  def leave_table(table_id, player_id) do
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

  def timeout_participant(attrs) do
    with {:ok, command} <-
           Poker.Repo.validate_changeset(attrs, &TimeoutParticipant.changeset/1),
         :ok <- Poker.App.dispatch(command, consistency: :strong) do
      :ok
    end
  end

  def get_tables() do
    Poker.Tables.Projections.TableList
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
    Poker.Repo.all(Poker.Tables.Projections.TableList)
  end

  @doc """
  Get player-specific game view with all calculated state.
  Use this instead of get_table for game UI.

  Parameters:
    - table_id: The table UUID
    - player_id: The player UUID
    - since_version: Optional stream version of last processed event (nil for full replay)
  """
  def get_player_game_view(table_id, player_id, since_version \\ nil) do
    Poker.Tables.Views.PlayerGameView.build(table_id, player_id, since_version)
  end
end
