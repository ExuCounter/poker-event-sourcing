defmodule Poker.Services.HandEvaluator.Behaviour do
  @callback determine_winners(participant_hands :: list(), community_cards :: list()) :: list()
end
