defmodule Poker.Tournaments do
  alias Poker.Tournaments.Commands.{CreateTournament, RegisterPlayer}
  alias Poker.Tournaments.Queries

  def create_tournament(creator_id, attrs) do
    tournament_id = UUIDv7.generate()

    command_attrs =
      Map.merge(attrs, %{
        tournament_id: tournament_id,
        creator_id: creator_id
      })

    with {:ok, command} <- Poker.Repo.validate_changeset(command_attrs, &CreateTournament.changeset/1),
         :ok <- Poker.App.dispatch(command, consistency: :strong) do
      {:ok, %{tournament_id: tournament_id}}
    end
  end

  def register_player(tournament_id, player_id) do
    with {:ok, tournament} <- get_tournament(tournament_id) do
      register_player_with_buyin(tournament_id, player_id, tournament.buy_in)
    end
  end

  defp register_player_with_buyin(tournament_id, player_id, buy_in) do
    with {:reserve_funds, :ok} <-
           {:reserve_funds, Poker.Wallet.reserve_funds(player_id, tournament_id, buy_in)},
         {:register, :ok} <-
           {:register, dispatch_register(tournament_id, player_id)} do
      :ok
    else
      {failed_step, error} ->
        Poker.Saga.compensate(failed_step, [
          {:reserve_funds, fn -> Poker.Wallet.release_funds(player_id, tournament_id, buy_in) end}
        ])

        error
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

  def list_tournaments do
    Queries.base()
    |> Queries.order_by_newest()
    |> Poker.Repo.all()
  end
end
