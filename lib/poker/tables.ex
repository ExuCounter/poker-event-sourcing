defmodule Poker.Tables do
  alias Poker.Tables.Commands.{
    CreateTable,
    JoinTableParticipant,
    StartTable,
    ParticipantActInHand,
    SitOutParticipant,
    SitInParticipant
  }

  def create_table(creator_id, settings_attrs \\ %{}) do
    table_id = Ecto.UUID.generate()
    creator_participant_id = Ecto.UUID.generate()
    settings_id = Ecto.UUID.generate()

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

  def join_participant(table, player, attrs \\ %{}) do
    participant_id = Ecto.UUID.generate()
    starting_stack = Map.get(attrs, :starting_stack)

    command_attrs = %{
      participant_id: participant_id,
      player_id: player.id,
      table_id: table.id,
      starting_stack: starting_stack
    }

    with {:ok, command} <-
           Poker.Repo.validate_changeset(command_attrs, &JoinTableParticipant.changeset/1),
         :ok <- Poker.App.dispatch(command, consistency: :strong) do
      {:ok, participant_id}
    end
  end

  def start_table(table) do
    hand_id = Ecto.UUID.generate()

    command_attrs = %{
      table_id: table.id,
      hand_id: hand_id
    }

    with {:ok, command} <- Poker.Repo.validate_changeset(command_attrs, &StartTable.changeset/1),
         :ok <- Poker.App.dispatch(command, consistency: :strong) do
      {:ok, hand_id}
    end
  end

  def fold_hand(table_id, participant_id) do
    act_in_hand(table_id, participant_id, %{action: :fold})
  end

  def check_hand(table_id, participant_id) do
    act_in_hand(table_id, participant_id, %{action: :check})
  end

  def call_hand(table_id, participant_id) do
    act_in_hand(table_id, participant_id, %{action: :call})
  end

  def raise_hand(table_id, participant_id, amount) do
    act_in_hand(table_id, participant_id, %{action: :raise, amount: amount})
  end

  def all_in_hand(table_id, participant_id) do
    act_in_hand(table_id, participant_id, %{action: :all_in})
  end

  def sit_out(participant) do
    command_attrs = %{
      participant_id: participant.id,
      table_id: participant.table_id
    }

    with {:ok, command} <-
           Poker.Repo.validate_changeset(command_attrs, &SitOutParticipant.changeset/1),
         :ok <- Poker.App.dispatch(command, consistency: :strong) do
      :ok
    end
  end

  def sit_in(participant) do
    command_attrs = %{
      participant_id: participant.id,
      table_id: participant.table_id
    }

    with {:ok, command} <-
           Poker.Repo.validate_changeset(command_attrs, &SitInParticipant.changeset/1),
         :ok <- Poker.App.dispatch(command, consistency: :strong) do
      :ok
    end
  end

  defp act_in_hand(table_id, participant_id, action_attrs) do
    hand_action_id = Ecto.UUID.generate()

    command_attrs =
      Map.merge(action_attrs, %{
        hand_action_id: hand_action_id,
        participant_id: participant_id,
        table_id: table_id
      })

    with {:ok, command} <-
           Poker.Repo.validate_changeset(command_attrs, &ParticipantActInHand.changeset/1),
         :ok <- Poker.App.dispatch(command, consistency: :strong) do
      :ok
    end
  end
end
