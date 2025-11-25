defmodule Poker.Services.HandEvaluator do
  @behaviour Poker.Services.HandEvaluator.Behaviour

  @impl true
  def determine_winners(participant_hands, community_cards) do
    config(:dispatcher).determine_winners(participant_hands, community_cards)
  end

  def config(key) do
    Keyword.fetch!(Application.fetch_env!(:poker, __MODULE__), key)
  end
end
