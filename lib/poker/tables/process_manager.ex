defmodule Poker.Tables.ProcessManager do
  use Commanded.ProcessManagers.ProcessManager,
    application: Poker.App,
    name: "Poker.Tables.ProcessManager",
    consistency: :strong

  # alias Poker.Tables.Events.{TableCreated, TableSettingsCreated, TableParticipantJoined}
  # alias Poker.Tables.Commands.{CreateTableSettings, JoinTableParticipant}

  # @derive Jason.Encoder
  # defstruct [:id, :creator_id, :settings]

  # def interested?(%TableCreated{id: table_id} = _event, _metadata) do
  #   {:start, table_id}
  # end

  # def interested?(%TableSettingsCreated{table_id: table_id} = _event, _metadata) do
  #   {:continue, table_id}
  # end

  # def interested?(%TableParticipantJoined{table_id: table_id} = _event, _metadata) do
  #   {:continue, table_id}
  # end

  # def interested?(_event, _metadata), do: false

  # def handle(%Poker.Tables.ProcessManager{}, %TableCreated{settings: settings} = _event) do
  #   struct(CreateTableSettings, settings)
  # end

  # def handle(
  #       %Poker.Tables.ProcessManager{id: table_uuid, creator_id: player_uuid} = state,
  #       %TableSettingsCreated{starting_stack: starting_stack} = event
  #     ) do
  #   struct(JoinTableParticipant, %{
  #     participant_uuid: Ecto.UUID.generate(),
  #     table_uuid: table_uuid,
  #     player_uuid: player_uuid,
  #     chips: starting_stack
  #   })
  # end

  # def apply(%__MODULE__{} = state, %TableCreated{id: table_id, creator_id: creator_id} = event) do
  #   %__MODULE__{state | id: table_id, creator_id: creator_id}
  # end

  # def apply(%__MODULE__{} = state, %TableSettingsCreated{} = settings) do
  #   %__MODULE__{state | settings: settings}
  # end
end
