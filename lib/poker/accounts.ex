defmodule Poker.Accounts do
  alias Poker.Accounts.Commands.{RegisterPlayer}
  alias Poker.Accounts.Projections.{Player}

  def register_player(attrs) do
    uuid = Ecto.UUID.generate()
    register_player = attrs |> Map.put(:player_uuid, uuid) |> RegisterPlayer.validate()

    with :ok <- is_email_available?(attrs.email),
         :ok <- Poker.App.dispatch(register_player, consistency: :strong) do
      get(Player, uuid)
    end
  end

  defp get(schema, uuid) do
    case Poker.Repo.get(schema, uuid) do
      nil -> {:error, :not_found}
      projection -> {:ok, projection}
    end
  end

  defp is_email_available?(email) do
    case Poker.Repo.get_by(Player, email: email) do
      nil -> :ok
      _projection -> {:error, :email_already_registered}
    end
  end
end
