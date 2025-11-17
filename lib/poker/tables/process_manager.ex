defmodule Poker.Tables.ProcessManager do
  use Commanded.ProcessManagers.ProcessManager,
    application: Poker.App,
    name: "Poker.Tables.ProcessManager",
    consistency: :strong

  alias Poker.Tables.Events.{TableStarted, RoundCompleted}
  alias Poker.Tables.Commands.{StartHand, StartRound}

  @derive Jason.Encoder
  defstruct [:id]

  def interested?(%TableStarted{id: table_id} = _event, _metadata) do
    {:start, table_id}
  end

  def interested?(%RoundCompleted{table_id: table_id} = _event, _metadata) do
    {:continue, table_id}
  end

  # def interested?(%TableParticipantJoined{table_id: table_id} = _event, _metadata) do
  #   {:continue, table_id}
  # end

  # def interested?(_event, _metadata), do: false

  def handle(
        %Poker.Tables.ProcessManager{},
        %TableStarted{id: table_id, dealer_button_id: dealer_button_id, hand_id: hand_id} = _event
      ) do
    struct(StartHand, %{
      table_id: table_id,
      hand_id: hand_id,
      dealer_button_id: dealer_button_id
    })
  end

  def handle(
        %Poker.Tables.ProcessManager{},
        %RoundCompleted{} = event
      ) do
    struct(StartRound, %{
      round_id: Ecto.UUID.generate(),
      round: next_round(event.type |> String.to_existing_atom()),
      table_id: event.table_id,
      hand_id: event.hand_id
    })
  end

  # def handle(
  #       %Poker.Tables.ProcessManager{id: table_id, creator_id: player_id} = state,
  #       %TableSettingsCreated{starting_stack: starting_stack} = event
  #     ) do
  #   struct(JoinTableParticipant, %{
  #     participant_id: Ecto.UUID.generate(),
  #     table_id: table_id,
  #     player_id: player_id,
  #     chips: starting_stack
  #   })
  # end

  def apply(%__MODULE__{} = state, %TableStarted{id: id} = _event) do
    %__MODULE__{state | id: id}
  end

  # def apply(%__MODULE__{} = state, %TableSettingsCreated{} = settings) do
  #   %__MODULE__{state | settings: settings}
  # end

  def next_round(round) do
    case round do
      :pre_flop -> :flop
      :flop -> :turn
      :turn -> :river
    end
  end
end
