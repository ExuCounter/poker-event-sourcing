defmodule Poker.Tournaments do
  alias Poker.Tournaments.Commands.{CreateTournament, RegisterPlayer}
  alias Poker.Tournaments.Queries

  def create_tournament(creator_id, attrs) do
    tournament_id = UUIDv7.generate()

    command_attrs =
      Map.merge(attrs, %{
        tournament_id: tournament_id,
        creator_id: creator_id,
        code: Poker.JoinCodes.next_code()
      })

    with {:ok, command} <- Poker.Repo.validate_changeset(command_attrs, &CreateTournament.changeset/1),
         :ok <- Poker.App.dispatch(command, consistency: :strong) do
      {:ok, %{tournament_id: tournament_id}}
    end
  end

  def register_player(tournament_id, player_id) do
    with {:ok, tournament} <- get_tournament(tournament_id),
         :ok <- Poker.Wallet.reserve_funds(player_id, tournament_id, tournament.buy_in) do
      case dispatch_register(tournament_id, player_id) do
        :ok ->
          :ok

        error ->
          Poker.Wallet.release_funds(player_id, tournament_id, tournament.buy_in)
          error
      end
    end
  end

  defp dispatch_register(tournament_id, player_id) do
    command_attrs = %{tournament_id: tournament_id, player_id: player_id}

    with {:ok, command} <- Poker.Repo.validate_changeset(command_attrs, &RegisterPlayer.changeset/1),
         :ok <- Poker.App.dispatch(command, consistency: :strong) do
      :ok
    end
  end

  def get_tournament(tournament_id) do
    case Queries.by_id(tournament_id) |> Poker.Repo.one() do
      nil -> {:error, :tournament_not_found}
      tournament -> {:ok, tournament}
    end
  end

  def get_tournament_by_code(code) do
    case Queries.by_code(code) |> Poker.Repo.one() do
      nil -> {:error, :tournament_not_found}
      tournament -> {:ok, tournament}
    end
  end

  def list_tournaments do
    Queries.base()
    |> Queries.order_by_newest()
    |> Poker.Repo.all()
  end
end
