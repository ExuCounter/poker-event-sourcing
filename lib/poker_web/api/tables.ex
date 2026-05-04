defmodule PokerWeb.Api.Tables do
  def list_tables() do
    Poker.Tables.list_tables()
  end

  def get_lobby(table_id) do
    Poker.Tables.get_lobby(table_id)
  end

  def get_player_game_view(%{user: user} = _scope, table_id, opts \\ []) do
    Poker.Tables.get_player_game_view(table_id, user.id, opts)
  end

  def list_hand_history(%{user: user} = _scope, opts \\ []) do
    Poker.Tables.Queries.HandHistory.list_for_player(user.id, opts)
  end

  def create_table(%{user: user} = _scope, settings) do
    Poker.Tables.create_table(user.id, settings)
  end

  def join_participant(%{user: user} = _scope, %{table_id: table_id, seat_number: seat_number}) do
    Poker.Tables.join_participant(table_id, user.id, %{nickname: user.nickname, seat_number: seat_number})
  end

  # Auto-assign seat for tournaments (no seat_number provided)
  def join_participant(%{user: user} = _scope, %{table_id: table_id}) do
    # Get lobby to find available seats
    lobby = Poker.Tables.get_lobby(table_id)
    occupied_seats = Enum.map(lobby.participants, & &1.seat_number)
    all_seats = 1..lobby.seats_count

    # Find first available seat
    case Enum.find(all_seats, fn seat -> seat not in occupied_seats end) do
      nil ->
        {:error, %{message: "No seats available"}}

      seat_number ->
        Poker.Tables.join_participant(table_id, user.id, %{nickname: user.nickname, seat_number: seat_number})
    end
  end

  def start_table(scope, table_id) do
    with :ok <- Poker.Tables.Policy.authorize(:start_table, scope, table_id) do
      Poker.Tables.start_table(table_id)
    end
  end

  # Player Actions

  def fold_hand(%{user: user} = _scope, table_id) do
    Poker.Tables.fold_hand(table_id, user.id)
  end

  def check_hand(%{user: user} = _scope, table_id) do
    Poker.Tables.check_hand(table_id, user.id)
  end

  def call_hand(%{user: user} = _scope, table_id) do
    Poker.Tables.call_hand(table_id, user.id)
  end

  def raise_hand(%{user: user} = _scope, table_id, amount) do
    Poker.Tables.raise_hand(table_id, user.id, amount)
  end

  def all_in_hand(%{user: user} = _scope, table_id) do
    Poker.Tables.all_in_hand(table_id, user.id)
  end

  def sit_out_participant(%{user: user} = _scope, table_id) do
    Poker.Tables.sit_out_participant(table_id, user.id)
  end

  def sit_in_participant(%{user: user} = _scope, table_id) do
    Poker.Tables.sit_in_participant(table_id, user.id)
  end

  def leave_table(%{user: user} = _scope, table_id) do
    Poker.Tables.leave_table(table_id, user.id)
  end
end
