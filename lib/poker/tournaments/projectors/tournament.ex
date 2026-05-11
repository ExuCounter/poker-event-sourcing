defmodule Poker.Tournaments.Projectors.Tournament do
  use Commanded.Projections.Ecto,
    application: Poker.App,
    repo: Poker.Repo,
    name: __MODULE__,
    consistency: :strong

  alias Poker.Tournaments.Events.{
    TournamentCreated,
    PlayerRegistered,
    TournamentStarted,
    BlindLevelAdvanced,
    TournamentPlayerBusted,
    TournamentFinished
  }

  alias Poker.Tournaments.Projections.Tournament

  project(%TournamentCreated{} = event, _metadata, fn multi ->
    Ecto.Multi.insert(multi, :tournament, %Tournament{
      id: event.id,
      creator_id: event.creator_id,
      code: event.code,
      status: event.status,
      speed: event.speed,
      buy_in: event.buy_in,
      starting_stack: event.starting_stack,
      table_type: event.table_type,
      max_players: event.max_players,
      registered_count: 0,
      players_remaining: 0,
      current_level: 1,
      prize_pool: 0
    })
  end)

  project(%PlayerRegistered{tournament_id: tournament_id, player_id: player_id}, _metadata, fn multi ->
    Ecto.Multi.update_all(
      multi,
      :tournament,
      from(tournament in Tournament,
        where: tournament.id == ^tournament_id
      ),
      inc: [registered_count: 1],
      push: [player_ids: player_id]
    )
  end)

  project(%TournamentStarted{tournament_id: tournament_id}, metadata, fn multi ->
    now = metadata.created_at

    Ecto.Multi.run(multi, :tournament, fn repo, _ ->
      tournament = repo.get!(Tournament, tournament_id)

      {_, _} =
        repo.update_all(
          from(t in Tournament, where: t.id == ^tournament_id),
          set: [status: :active, players_remaining: tournament.registered_count, level_started_at: now]
        )

      {:ok, nil}
    end)
  end)

  project(%BlindLevelAdvanced{tournament_id: tournament_id, level: level}, metadata, fn multi ->
    now = metadata.created_at

    Ecto.Multi.update_all(
      multi,
      :tournament,
      from(tournament in Tournament,
        where: tournament.id == ^tournament_id
      ),
      set: [current_level: level, level_started_at: now]
    )
  end)

  project(%TournamentPlayerBusted{tournament_id: tournament_id}, _metadata, fn multi ->
    Ecto.Multi.update_all(
      multi,
      :tournament,
      from(tournament in Tournament,
        where: tournament.id == ^tournament_id
      ),
      inc: [players_remaining: -1]
    )
  end)

  project(%TournamentFinished{tournament_id: tournament_id, prize_pool: prize_pool}, _metadata, fn multi ->
    Ecto.Multi.update_all(
      multi,
      :tournament,
      from(tournament in Tournament,
        where: tournament.id == ^tournament_id
      ),
      set: [status: :finished, prize_pool: prize_pool]
    )
  end)
end
