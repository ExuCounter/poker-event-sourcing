defmodule Poker.Tables.Projections.HandSummaryParticipantResult do
  use Poker, :schema

  @primary_key false
  schema "hand_summary_participant_results" do
    field :hand_id, :binary_id, primary_key: true
    field :player_id, :binary_id, primary_key: true
    field :amount_won, :integer, default: 0

    timestamps()
  end
end
