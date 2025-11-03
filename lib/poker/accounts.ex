defmodule Poker.Accounts do
  alias Poker.Accounts.Commands.{RegisterPlayer}
  alias Poker.Accounts.Projections.{Player}

  def register_player(attrs) do
    uuid = Ecto.UUID.generate()
    register_player = attrs |> Map.put(:player_uuid, uuid) |> RegisterPlayer.validate()

    with :ok <- Poker.App.dispatch(register_player, consistency: :strong) do
      get(Player, uuid)
    end
  end

  defp get(schema, uuid) do
    case Poker.Repo.get(schema, uuid) do
      nil -> {:error, :not_found}
      projection -> {:ok, projection}
    end
  end
end
