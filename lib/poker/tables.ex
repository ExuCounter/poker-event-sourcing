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

  def join_participant(table_id, player_id, attrs \\ %{}) do
    participant_id = Ecto.UUID.generate()
    starting_stack = Map.get(attrs, :starting_stack)

    command_attrs = %{
      participant_id: participant_id,
      player_id: player_id,
      table_id: table_id,
      starting_stack: starting_stack
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
         :ok <- Poker.App.dispatch(command, consistency: :strong) do
      {:ok, :table_started}
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

  def get_tables() do
    Poker.Repo.all(Poker.Tables.Projections.TableList)
  end

  def get_lobby(table_id) do
    Poker.Repo.get(Poker.Tables.Projections.TableLobby, table_id)
  end

  def get_table(table_id) do
    with {:ok, table} <- Poker.Repo.get_by(Poker.Tables.Projections.Table, table_id: table_id) do
      table = table |> Poker.Repo.preload([:participants, hands: [:rounds]])

      {:ok, table}
    end
  end

  def get_table_state(table_id, current_user_id) do
    with {:ok, table_state} <- Poker.Repo.get(Poker.Tables.Projections.TableState, table_id) do
      # filtered_hands =
      #   Enum.map(state.participant_hands, fn hand ->
      #     participant =
      #       Enum.find(lobby.participants, &(&1.player_id == hand.participant_id))

      #     if participant && participant.player_id == current_user_id do
      #       hand
      #     else
      #       %{hand | hole_cards: []}
      #     end
      #   end)

      # %{state | participant_hands: filtered_hands}
      {:ok, table_state}
    end
  end

  def list_tables() do
    Poker.Repo.all(Poker.Tables.Projections.TableList)
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
