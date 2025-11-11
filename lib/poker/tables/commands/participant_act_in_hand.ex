defmodule Poker.Tables.Commands.ParticipantActInHand do
  use Poker, :schema

  embedded_schema do
    field :hand_action_id, :binary_id
    field :participant_id, :binary_id
    field :table_id, :binary_id
    field :action, Ecto.Enum, values: [:fold, :check, :call, :raise, :all_in]
    field :amount, :integer
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> Ecto.Changeset.cast(attrs, [
      :hand_action_id,
      :participant_id,
      :table_id,
      :action,
      :amount
    ])
    |> Ecto.Changeset.validate_required([
      :hand_action_id,
      :participant_id,
      :table_id,
      :action
    ])
    |> validate_amount_for_action()
  end

  defp validate_amount_for_action(changeset) do
    action = Ecto.Changeset.get_field(changeset, :action)
    amount = Ecto.Changeset.get_field(changeset, :amount)

    case {action, amount} do
      {:raise, nil} ->
        Ecto.Changeset.add_error(changeset, :amount, "is required for raise action")

      _ ->
        changeset
    end
  end
end
