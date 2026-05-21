defmodule PokerWeb.Api.Tables do
  def list_tables(scope) do
    with :ok <- Bodyguard.permit(Poker.Tables.Policy, :list_tables, scope) do
      Poker.Tables.list_tables()
    end
  end

  def get_lobby(scope, table_id) do
    with :ok <- Bodyguard.permit(Poker.Tables.Policy, :get_lobby, scope) do
      Poker.Tables.get_lobby(table_id)
    end
  end

  def get_player_game_view(scope, table_id, opts \\ []) do
    with :ok <- Bodyguard.permit(Poker.Tables.Policy, :get_player_game_view, scope) do
      Poker.Tables.get_player_game_view(table_id, scope.user.id, opts)
    end
  end

  def list_hand_history(scope, opts \\ []) do
    with :ok <- Bodyguard.permit(Poker.Tables.Policy, :list_hand_history, scope) do
      Poker.Tables.Queries.HandHistory.list_for_player(scope.user.id, opts)
    end
  end

  def create_table(scope, settings) do
    with :ok <- Bodyguard.permit(Poker.Tables.Policy, :create_table, scope, settings) do
      Poker.Tables.create_table(scope.user.id, settings)
    end
  end

  def join_participant(scope, %{table_id: table_id} = args) do
    with :ok <- Bodyguard.permit(Poker.Tables.Policy, :join_participant, scope, args) do
      Poker.Tables.join_participant(table_id, scope.user.id, %{
        nickname: scope.user.nickname,
        seat_number: Map.get(args, :seat_number)
      })
    end
  end

  def start_table(scope, table_id) do
    with :ok <- Poker.Tables.Policy.authorize(:start_table, scope, table_id) do
      Poker.Tables.start_table(table_id)
    end
  end

  def fold_hand(scope, table_id) do
    with :ok <- Bodyguard.permit(Poker.Tables.Policy, :fold_hand, scope, table_id) do
      Poker.Tables.fold_hand(table_id, scope.user.id)
    end
  end

  def check_hand(scope, table_id) do
    with :ok <- Bodyguard.permit(Poker.Tables.Policy, :check_hand, scope, table_id) do
      Poker.Tables.check_hand(table_id, scope.user.id)
    end
  end

  def call_hand(scope, table_id) do
    with :ok <- Bodyguard.permit(Poker.Tables.Policy, :call_hand, scope, table_id) do
      Poker.Tables.call_hand(table_id, scope.user.id)
    end
  end

  def raise_hand(scope, table_id, amount) do
    with :ok <- Bodyguard.permit(Poker.Tables.Policy, :raise_hand, scope, table_id) do
      Poker.Tables.raise_hand(table_id, scope.user.id, amount)
    end
  end

  def all_in_hand(scope, table_id) do
    with :ok <- Bodyguard.permit(Poker.Tables.Policy, :all_in_hand, scope, table_id) do
      Poker.Tables.all_in_hand(table_id, scope.user.id)
    end
  end

  def sit_out_participant(scope, table_id) do
    with :ok <- Bodyguard.permit(Poker.Tables.Policy, :sit_out_participant, scope, table_id) do
      Poker.Tables.sit_out_participant(table_id, scope.user.id)
    end
  end

  def sit_in_participant(scope, table_id) do
    with :ok <- Bodyguard.permit(Poker.Tables.Policy, :sit_in_participant, scope, table_id) do
      Poker.Tables.sit_in_participant(table_id, scope.user.id)
    end
  end

  def leave_table(scope, table_id) do
    with :ok <- Bodyguard.permit(Poker.Tables.Policy, :leave_table, scope, table_id) do
      Poker.Tables.leave_table(table_id, scope.user.id)
    end
  end
end
