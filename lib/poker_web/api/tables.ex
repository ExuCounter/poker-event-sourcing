defmodule PokerWeb.Api.Tables do
  import Ecto.Query

  def list_tables() do
    Poker.Tables.list_tables()
  end

  def get_lobby(table_id) do
    Poker.Tables.get_lobby(table_id)
  end

  def get_table(table_id) do
    Poker.Tables.get_table(table_id)
  end

  def create_table(%{user: user} = _scope, settings) do
    Poker.Tables.create_table(user.id, settings)
  end

  def join_participant(%{user: user} = _scope, %{table_id: table_id}) do
    Poker.Tables.join_participant(table_id, user.id)
  end

  def start_table(%{user: _user} = _scope, table_id) do
    Poker.Tables.start_table(table_id)
  end

  # Player Actions

  def fold_hand(%{user: user} = _scope, table_id) do
    with {:ok, participant_id} <- find_participant_id(table_id, user.id) do
      Poker.Tables.fold_hand(table_id, participant_id)
    end
  end

  def check_hand(%{user: user} = _scope, table_id) do
    with {:ok, participant_id} <- find_participant_id(table_id, user.id) do
      Poker.Tables.check_hand(table_id, participant_id)
    end
  end

  def call_hand(%{user: user} = _scope, table_id) do
    with {:ok, participant_id} <- find_participant_id(table_id, user.id) do
      Poker.Tables.call_hand(table_id, participant_id)
    end
  end

  def raise_hand(%{user: user} = _scope, table_id, amount) do
    with {:ok, participant_id} <- find_participant_id(table_id, user.id) do
      Poker.Tables.raise_hand(table_id, participant_id, amount)
    end
  end

  def all_in_hand(%{user: user} = _scope, table_id) do
    with {:ok, participant_id} <- find_participant_id(table_id, user.id) do
      Poker.Tables.all_in_hand(table_id, participant_id)
    end
  end

  # Helper Functions

  defp find_participant_id(table_id, player_id) do
    query =
      from(p in Poker.Tables.Projections.TableParticipants,
        where: p.table_id == ^table_id and p.player_id == ^player_id,
        select: p.id
      )

    case Poker.Repo.one(query) do
      nil -> {:error, %{status: :participant_not_found, message: "You are not a participant at this table"}}
      participant_id -> {:ok, participant_id}
    end
  end
end
