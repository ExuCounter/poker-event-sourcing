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

  @impl Commanded.Projections.Ecto
  def after_update(%TournamentCreated{id: tournament_id}, _metadata, _changes) do
    Poker.Tournaments.PubSub.broadcast_tournament_list(:tournament_created, %{tournament_id: tournament_id})
    :ok
  end

  def after_update(%PlayerRegistered{tournament_id: tournament_id, player_id: player_id}, _metadata, _changes) do
    Poker.Tournaments.PubSub.broadcast_tournament(tournament_id, :player_registered, %{player_id: player_id})
    Poker.Tournaments.PubSub.broadcast_tournament_list(:tournament_updated, %{tournament_id: tournament_id})
    :ok
  end

  def after_update(%TournamentStarted{tournament_id: tournament_id}, _metadata, _changes) do
    Poker.Tournaments.PubSub.broadcast_tournament(tournament_id, :tournament_started)
    :ok
  end

  def after_update(%BlindLevelAdvanced{tournament_id: tournament_id, level: level}, _metadata, _changes) do
    Poker.Tournaments.PubSub.broadcast_tournament(tournament_id, :blind_level_advanced, %{level: level})
    :ok
  end

  def after_update(%TournamentPlayerBusted{tournament_id: tournament_id}, _metadata, _changes) do
    Poker.Tournaments.PubSub.broadcast_tournament(tournament_id, :player_busted, %{})
    :ok
  end

  def after_update(%TournamentFinished{tournament_id: tournament_id}, _metadata, _changes) do
    Poker.Tournaments.PubSub.broadcast_tournament_list(:tournament_updated, %{tournament_id: tournament_id})
    :ok
  end

  def after_update(_event, _metadata, _changes), do: :ok

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
