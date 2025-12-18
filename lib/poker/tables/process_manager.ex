defmodule Poker.Tables.ProcessManager do
  use Commanded.ProcessManagers.ProcessManager,
    application: Poker.App,
    name: "Poker.Tables.ProcessManager",
    consistency: :strong

  alias Poker.Tables.Events.{TableStarted, RoundCompleted, TableFinished, HandFinished}
  alias Poker.Tables.Commands.{StartHand, StartRound, FinishHand}

  @derive Jason.Encoder
  defstruct [:id]

  def interested?(%TableStarted{id: table_id} = _event, _metadata) do
    {:start, table_id}
  end

  def interested?(%RoundCompleted{table_id: table_id} = event, _metadata) do
    {:continue, table_id}
  end

  def interested?(%HandFinished{table_id: table_id} = event, _metadata) do
    {:continue, table_id}
  end

  def interested?(%TableFinished{table_id: table_id} = event, _metadata) do
    {:stop, table_id}
  end

  def handle(
        %Poker.Tables.ProcessManager{},
        %TableStarted{id: table_id} = _event
      ) do
    struct(StartHand, %{table_id: table_id, hand_id: Ecto.UUID.generate()})
  end

  def handle(
        %Poker.Tables.ProcessManager{},
        %HandFinished{table_id: table_id} = _event
      ) do
    struct(StartHand, %{table_id: table_id, hand_id: Ecto.UUID.generate()})
  end

  def handle(
        %Poker.Tables.ProcessManager{},
        %RoundCompleted{} = event
      ) do
    round_type = event.type |> String.to_existing_atom()
    reason = event.reason |> String.to_existing_atom()

    cond do
      # If all players folded except one, finish the hand immediately
      reason == :all_folded ->
        struct(FinishHand, %{
          table_id: event.table_id,
          hand_id: event.hand_id,
          finish_reason: :all_folded
        })

      # If river round completed and all acted, go to showdown
      round_type == :river and reason == :all_acted ->
        struct(FinishHand, %{
          table_id: event.table_id,
          hand_id: event.hand_id,
          finish_reason: :showdown
        })

      # Otherwise, start next round
      reason == :all_acted ->
        struct(StartRound, %{
          round_id: Ecto.UUID.generate(),
          round: next_round(round_type),
          table_id: event.table_id,
          hand_id: event.hand_id
        })
    end
  end

  def apply(%__MODULE__{} = state, %TableStarted{id: id} = _event) do
    %__MODULE__{state | id: id}
  end

  def next_round(round) do
    case round do
      :pre_flop -> :flop
      :flop -> :turn
      :turn -> :river
    end
  end
end
