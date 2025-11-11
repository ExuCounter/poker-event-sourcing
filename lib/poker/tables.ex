defmodule Poker.Tables do
  alias Poker.Tables.Commands.{
    CreateTable,
    JoinTableParticipant,
    StartTable,
    ParticipantActInHand,
    SitOutParticipant,
    SitInParticipant
  }

  alias Poker.Tables.Projections.{Table, Participant}

  def create_table(creator, settings_attrs \\ %{}) do
    table_id = Ecto.UUID.generate()

    command_attrs = %{
      table_id: table_id,
      creator_id: creator.id,
      settings: settings_attrs
    }

    with {:ok, command} <- Poker.Repo.validate_changeset(command_attrs, &CreateTable.changeset/1),
         :ok <- Poker.App.dispatch(command, consistency: :strong) do
      Poker.Repo.find_by_id(Table, table_id)
    end
  end

  def join_participant(table, player) do
    participant_id = Ecto.UUID.generate()

    command_attrs = %{
      participant_id: participant_id,
      player_id: player.id,
      table_id: table.id
    }

    with {:ok, command} <-
           Poker.Repo.validate_changeset(command_attrs, &JoinTableParticipant.changeset/1),
         :ok <- Poker.App.dispatch(command, consistency: :strong) do
      Poker.Repo.find_by_id(Participant, participant_id)
    end
  end

  def start_table(table) do
    command_attrs = %{
      table_id: table.id
    }

    with {:ok, command} <- Poker.Repo.validate_changeset(command_attrs, &StartTable.changeset/1),
         :ok <- Poker.App.dispatch(command, consistency: :strong) do
      Poker.Repo.find_by_id(Table, table.id)
    end
  end

  def fold_hand(participant) do
    act_in_hand(participant, %{action: :fold})
  end

  def check_hand(participant) do
    act_in_hand(participant, %{action: :check})
  end

  def call_hand(participant) do
    act_in_hand(participant, %{action: :call})
  end

  def raise_hand(participant, amount) do
    act_in_hand(participant, %{action: :raise, amount: amount})
  end

  def all_in_hand(participant) do
    act_in_hand(participant, %{action: :all_in})
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

  defp act_in_hand(participant, action_attrs) do
    hand_action_id = Ecto.UUID.generate()

    command_attrs =
      Map.merge(action_attrs, %{
        hand_action_id: hand_action_id,
        participant_id: participant.id,
        table_id: participant.table_id
      })

    with {:ok, command} <-
           Poker.Repo.validate_changeset(command_attrs, &ParticipantActInHand.changeset/1),
         :ok <- Poker.App.dispatch(command, consistency: :strong) do
      :ok
    end
  end
end
