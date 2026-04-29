defmodule Poker.Tournaments.Projectors.TournamentTest do
  use Poker.DataCase

  alias Poker.Tournaments.Projectors.Tournament, as: Projector
  alias Poker.Tournaments.Projections.Tournament

  alias Poker.Tournaments.Events.{
    TournamentCreated,
    PlayerRegistered,
    TournamentStarted,
    BlindLevelAdvanced,
    TournamentPlayerBusted,
    TournamentFinished
  }

  setup do
    Poker.Tournaments.PubSub.subscribe_to_tournament_list()
    on_exit(fn -> Phoenix.PubSub.unsubscribe(Poker.PubSub, "tournament_list") end)
  end

  defp metadata do
    %{
      handler_name: "tournament_test",
      event_number: :erlang.unique_integer([:positive, :monotonic]),
      created_at: DateTime.utc_now()
    }
  end

  defp create_tournament(opts \\ %{}) do
    tournament_id = opts[:id] || Ecto.UUID.generate()

    event = %TournamentCreated{
      id: tournament_id,
      creator_id: opts[:creator_id] || Ecto.UUID.generate(),
      status: :registering,
      speed: opts[:speed] || :regular,
      buy_in: opts[:buy_in] || 100,
      starting_stack: opts[:starting_stack] || 1500,
      table_type: opts[:table_type] || :six_max,
      max_players: opts[:max_players] || 50
    }

    :ok = Projector.handle(event, metadata())
    tournament_id
  end

  defp register_player(tournament_id, player_id) do
    Poker.Tournaments.PubSub.subscribe_to_tournament(tournament_id)

    event = %PlayerRegistered{
      tournament_id: tournament_id,
      player_id: player_id
    }

    :ok = Projector.handle(event, metadata())
  end

  describe "TournamentCreated event" do
    test "inserts tournament with correct initial values" do
      tournament_id = create_tournament()

      assert_receive {:tournament_list, :tournament_created, %{tournament_id: ^tournament_id}}

      tournament = Repo.get(Tournament, tournament_id)

      assert tournament.id == tournament_id
      assert tournament.status == :registering
      assert tournament.registered_count == 0
      assert tournament.players_remaining == 0
      assert tournament.current_level == 1
      assert tournament.prize_pool == 0
      assert tournament.player_ids == []
    end
  end

  describe "PlayerRegistered event" do
    test "increments registered_count and pushes player_id to player_ids" do
      tournament_id = create_tournament()
      player_id = Ecto.UUID.generate()
      register_player(tournament_id, player_id)

      assert_receive {:tournament, :player_registered, %{tournament_id: ^tournament_id, player_id: ^player_id}}
      assert_receive {:tournament_list, :tournament_updated, %{tournament_id: ^tournament_id}}

      tournament = Repo.get(Tournament, tournament_id)

      assert tournament.registered_count == 1
      assert tournament.player_ids == [player_id]
    end

    test "accumulates multiple registrations" do
      tournament_id = create_tournament()
      player_id_1 = Ecto.UUID.generate()
      player_id_2 = Ecto.UUID.generate()
      register_player(tournament_id, player_id_1)
      register_player(tournament_id, player_id_2)

      tournament = Repo.get(Tournament, tournament_id)

      assert tournament.registered_count == 2
      assert tournament.player_ids == [player_id_1, player_id_2]
    end
  end

  describe "TournamentStarted event" do
    test "sets status to active, players_remaining to registered_count, and level_started_at from metadata" do
      tournament_id = create_tournament()
      Poker.Tournaments.PubSub.subscribe_to_tournament(tournament_id)
      register_player(tournament_id, Ecto.UUID.generate())
      register_player(tournament_id, Ecto.UUID.generate())

      meta = metadata()
      :ok = Projector.handle(%TournamentStarted{tournament_id: tournament_id}, meta)

      assert_receive {:tournament, :tournament_started, %{tournament_id: ^tournament_id}}

      tournament = Repo.get(Tournament, tournament_id)

      assert tournament.status == :active
      assert tournament.players_remaining == 2
      assert tournament.level_started_at != nil
    end
  end

  describe "BlindLevelAdvanced event" do
    test "updates current_level and level_started_at" do
      tournament_id = create_tournament()
      Poker.Tournaments.PubSub.subscribe_to_tournament(tournament_id)
      register_player(tournament_id, Ecto.UUID.generate())
      register_player(tournament_id, Ecto.UUID.generate())
      :ok = Projector.handle(%TournamentStarted{tournament_id: tournament_id}, metadata())

      meta = metadata()

      :ok =
        Projector.handle(
          %BlindLevelAdvanced{tournament_id: tournament_id, level: 2, small_blind: 20, big_blind: 40, duration_seconds: 600},
          meta
        )

      assert_receive {:tournament, :blind_level_advanced, %{tournament_id: ^tournament_id, level: 2}}

      tournament = Repo.get(Tournament, tournament_id)

      assert tournament.current_level == 2
      assert tournament.level_started_at != nil
    end
  end

  describe "TournamentPlayerBusted event" do
    test "decrements players_remaining" do
      tournament_id = create_tournament()
      Poker.Tournaments.PubSub.subscribe_to_tournament(tournament_id)
      register_player(tournament_id, Ecto.UUID.generate())
      register_player(tournament_id, Ecto.UUID.generate())
      :ok = Projector.handle(%TournamentStarted{tournament_id: tournament_id}, metadata())

      :ok =
        Projector.handle(
          %TournamentPlayerBusted{tournament_id: tournament_id, player_id: Ecto.UUID.generate()},
          metadata()
        )

      assert_receive {:tournament, :player_busted, %{tournament_id: ^tournament_id}}

      tournament = Repo.get(Tournament, tournament_id)

      assert tournament.players_remaining == 1
    end
  end

  describe "TournamentFinished event" do
    test "sets status to finished and prize_pool" do
      tournament_id = create_tournament()
      register_player(tournament_id, Ecto.UUID.generate())
      register_player(tournament_id, Ecto.UUID.generate())
      :ok = Projector.handle(%TournamentStarted{tournament_id: tournament_id}, metadata())

      :ok =
        Projector.handle(
          %TournamentFinished{tournament_id: tournament_id, prize_pool: 5000, payouts: []},
          metadata()
        )

      assert_receive {:tournament_list, :tournament_updated, %{tournament_id: ^tournament_id}}

      tournament = Repo.get(Tournament, tournament_id)

      assert tournament.status == :finished
      assert tournament.prize_pool == 5000
    end
  end
end
