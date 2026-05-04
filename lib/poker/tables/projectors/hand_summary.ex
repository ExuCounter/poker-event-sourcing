defmodule Poker.Tables.Projectors.HandSummary do
  use Commanded.Projections.Ecto,
    application: Poker.App,
    repo: Poker.Repo,
    name: __MODULE__,
    consistency: :strong

  import Ecto.Query

  alias Poker.Tables.Events.{
    HandStarted,
    SmallBlindPosted,
    BigBlindPosted,
    ParticipantHandGiven,
    ParticipantCalled,
    ParticipantRaised,
    ParticipantWentAllIn,
    PayoutDistributed,
    HandFinished
  }

  alias Poker.Tables.Projections.{
    HandSummary,
    HandSummaryParticipantResult,
    TableList,
    TableLobby
  }

  # Insert summary row when the hand starts.
  # TableList is guaranteed to exist (strong consistency, TableCreated precedes HandStarted).
  project(%HandStarted{id: hand_id, table_id: table_id}, fn multi ->
    table = Poker.Repo.get!(TableList, table_id)

    Ecto.Multi.insert(multi, :hand_summary, %HandSummary{
      id: Ecto.UUID.generate(),
      hand_id: hand_id,
      table_id: table_id,
      game_mode: table.game_mode,
      source_id: table.source_id,
      pot_total: 0
    })
  end)

  # Insert participant result row when cards are dealt.
  # Look up player_id from TableLobby using participant_id.
  project(
    %ParticipantHandGiven{hand_id: hand_id, table_id: table_id, participant_id: participant_id},
    fn multi ->
      lobby = Poker.Repo.get!(TableLobby, table_id)
      player_id = find_player_id(lobby, participant_id)

      Ecto.Multi.insert(
        multi,
        {:participant_result, participant_id},
        %HandSummaryParticipantResult{
          hand_id: hand_id,
          player_id: player_id,
          amount_won: 0,
          amount_invested: 0
        }
      )
    end
  )

  # Blind events fire after cards are dealt — row already exists, just increment amount_invested.
  project(%SmallBlindPosted{hand_id: hand_id, table_id: table_id, participant_id: participant_id, amount: amount}, fn multi ->
    lobby = Poker.Repo.get!(TableLobby, table_id)
    player_id = find_player_id(lobby, participant_id)

    Ecto.Multi.update_all(
      multi,
      {:invest_sb, participant_id},
      from(participant_result in HandSummaryParticipantResult,
        where: participant_result.hand_id == ^hand_id and participant_result.player_id == ^player_id
      ),
      inc: [amount_invested: amount]
    )
  end)

  project(%BigBlindPosted{hand_id: hand_id, table_id: table_id, participant_id: participant_id, amount: amount}, fn multi ->
    lobby = Poker.Repo.get!(TableLobby, table_id)
    player_id = find_player_id(lobby, participant_id)

    Ecto.Multi.update_all(
      multi,
      {:invest_bb, participant_id},
      from(participant_result in HandSummaryParticipantResult,
        where: participant_result.hand_id == ^hand_id and participant_result.player_id == ^player_id
      ),
      inc: [amount_invested: amount]
    )
  end)

  # Betting actions: accumulate amount_invested.
  project(%ParticipantCalled{hand_id: hand_id, table_id: table_id, participant_id: participant_id, amount: amount}, fn multi ->
    lobby = Poker.Repo.get!(TableLobby, table_id)
    player_id = find_player_id(lobby, participant_id)

    Ecto.Multi.update_all(
      multi,
      {:invest_call, participant_id},
      from(participant_result in HandSummaryParticipantResult,
        where: participant_result.hand_id == ^hand_id and participant_result.player_id == ^player_id
      ),
      inc: [amount_invested: amount]
    )
  end)

  project(%ParticipantRaised{hand_id: hand_id, table_id: table_id, participant_id: participant_id, amount: amount}, fn multi ->
    lobby = Poker.Repo.get!(TableLobby, table_id)
    player_id = find_player_id(lobby, participant_id)

    Ecto.Multi.update_all(
      multi,
      {:invest_raise, participant_id},
      from(participant_result in HandSummaryParticipantResult,
        where: participant_result.hand_id == ^hand_id and participant_result.player_id == ^player_id
      ),
      inc: [amount_invested: amount]
    )
  end)

  project(%ParticipantWentAllIn{hand_id: hand_id, table_id: table_id, participant_id: participant_id, amount: amount}, fn multi ->
    lobby = Poker.Repo.get!(TableLobby, table_id)
    player_id = find_player_id(lobby, participant_id)

    Ecto.Multi.update_all(
      multi,
      {:invest_allin, participant_id},
      from(participant_result in HandSummaryParticipantResult,
        where: participant_result.hand_id == ^hand_id and participant_result.player_id == ^player_id
      ),
      inc: [amount_invested: amount]
    )
  end)

  # Accumulate pot_total on the summary and amount_won on the participant result.
  # Set winner fields when the main or combined pot is distributed.
  project(%PayoutDistributed{} = event, fn multi ->
    lobby = Poker.Repo.get!(TableLobby, event.table_id)
    player_id = find_player_id(lobby, event.participant_id)

    multi =
      if player_id do
        Ecto.Multi.update_all(
          multi,
          {:increment_participant, event.participant_id},
          from(participant_result in HandSummaryParticipantResult,
            where: participant_result.hand_id == ^event.hand_id and participant_result.player_id == ^player_id
          ),
          inc: [amount_won: event.amount]
        )
      else
        multi
      end

    multi
    |> Ecto.Multi.update_all(
      {:increment_pot, event.hand_id},
      from(hand_summary in HandSummary, where: hand_summary.hand_id == ^event.hand_id),
      inc: [pot_total: event.amount]
    )
    |> maybe_set_winner(event, player_id)
  end)

  # Set finish_reason when the hand ends.
  project(%HandFinished{hand_id: hand_id, finish_reason: finish_reason}, fn multi ->
    Ecto.Multi.update_all(
      multi,
      :set_finish_reason,
      from(hand_summary in HandSummary, where: hand_summary.hand_id == ^hand_id),
      set: [finish_reason: finish_reason]
    )
  end)

  defp maybe_set_winner(multi, %PayoutDistributed{pot_type: pot_type} = event, player_id)
       when pot_type in [:main, :combined] do
    encoded_rank = encode_hand_rank(event.hand_rank)

    Ecto.Multi.update_all(
      multi,
      :set_winner,
      from(hand_summary in HandSummary, where: hand_summary.hand_id == ^event.hand_id),
      set: [
        winner_player_id: player_id,
        winner_hand_rank: encoded_rank
      ]
    )
  end

  defp maybe_set_winner(multi, _event, _player_id), do: multi

  defp find_player_id(%TableLobby{participants: participants}, participant_id) do
    case Enum.find(participants, fn p -> p.participant_id == participant_id end) do
      nil -> nil
      participant -> participant.player_id
    end
  end

  defp encode_hand_rank(nil), do: nil
  defp encode_hand_rank(rank) when is_tuple(rank), do: Poker.Services.HandRank.to_display_name(rank)
end
