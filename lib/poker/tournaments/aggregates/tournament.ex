defmodule Poker.Tournaments.Aggregates.Tournament do
  alias Poker.Tournaments.Commands.{
    CreateTournament,
    RegisterPlayer,
    AdvanceBlindLevel,
    RecordPlayerBust,
    RecordTournamentTable,
    FinishTournament
  }

  alias Poker.Tournaments.Events.{
    TournamentCreated,
    PlayerRegistered,
    TournamentStarted,
    BlindLevelAdvanced,
    TournamentPlayerBusted,
    TournamentTableCreated,
    TournamentFinished
  }

  alias Poker.Tournaments.BlindStructure

  defstruct [
    :id,
    :creator_id,
    :status,
    :speed,
    :buy_in,
    :starting_stack,
    :table_type,
    :max_players,
    :current_level,
    table_ids: [],
    registered_players: [],
    busted_players: []
  ]

  # COMMAND HANDLERS

  def execute(%__MODULE__{id: nil}, %CreateTournament{} = cmd) do
    starting_stack = BlindStructure.starting_stack(cmd.speed)
    max_players = BlindStructure.max_players(cmd.table_type)

    %TournamentCreated{
      id: cmd.tournament_id,
      creator_id: cmd.creator_id,
      status: :registering,
      speed: cmd.speed,
      buy_in: cmd.buy_in,
      starting_stack: starting_stack,
      table_type: cmd.table_type,
      max_players: max_players
    }
  end

  def execute(%__MODULE__{id: _existing}, %CreateTournament{}) do
    {:error, :tournament_already_exists}
  end

  def execute(%__MODULE__{id: nil}, _cmd) do
    {:error, :tournament_not_found}
  end

  def execute(%__MODULE__{status: status}, %RegisterPlayer{}) when status != :registering do
    {:error, :registration_closed}
  end

  def execute(%__MODULE__{registered_players: players, max_players: max} = tournament, %RegisterPlayer{} = cmd) do
    cond do
      Enum.any?(players, &(&1 == cmd.player_id)) ->
        {:error, :already_registered}

      length(players) >= max ->
        {:error, :tournament_full}

      true ->
        events = [
          %PlayerRegistered{
            tournament_id: tournament.id,
            player_id: cmd.player_id
          }
        ]

        if length(players) + 1 == max do
          events ++ [%TournamentStarted{tournament_id: tournament.id}]
        else
          events
        end
    end
  end

  def execute(%__MODULE__{id: id, status: :active, current_level: current, speed: speed}, %AdvanceBlindLevel{level: level}) do
    cond do
      level != current + 1 ->
        {:error, :invalid_blind_level}

      level > BlindStructure.max_level() ->
        {:error, :max_blind_level_reached}

      true ->
        blind = BlindStructure.get_level(level)
        duration = BlindStructure.duration_seconds(speed)

        %BlindLevelAdvanced{
          tournament_id: id,
          level: level,
          small_blind: blind.small_blind,
          big_blind: blind.big_blind,
          duration_seconds: duration
        }
    end
  end

  def execute(%__MODULE__{status: status}, %AdvanceBlindLevel{}) when status != :active do
    {:error, :tournament_not_active}
  end

  def execute(%__MODULE__{status: :active} = tournament, %RecordPlayerBust{} = cmd) do
    if Enum.any?(tournament.busted_players, &(&1 == cmd.player_id)) do
      {:error, :player_already_busted}
    else
      %TournamentPlayerBusted{
        tournament_id: tournament.id,
        player_id: cmd.player_id
      }
    end
  end

  def execute(%__MODULE__{} = tournament, %RecordTournamentTable{} = cmd) do
    if Enum.any?(tournament.table_ids, &(&1 == cmd.table_id)) do
      {:error, :table_already_recorded}
    else
      %TournamentTableCreated{
        tournament_id: tournament.id,
        table_id: cmd.table_id
      }
    end
  end

  def execute(%__MODULE__{status: :active} = tournament, %FinishTournament{}) do
    busted_ids = MapSet.new(tournament.busted_players)
    winner = Enum.find(tournament.registered_players, &(not MapSet.member?(busted_ids, &1)))
    total_players = length(tournament.registered_players)
    prize_pool = total_players * tournament.buy_in

    payout_structure = BlindStructure.calculate_payouts(total_players, tournament.buy_in)
    placements = build_final_placements(winner, tournament.busted_players)

    payouts =
      Enum.map(payout_structure, fn %{position: pos, payout_amount: amount} ->
        player = Enum.find(placements, &(&1.position == pos))
        %{player_id: player.player_id, position: pos, payout_amount: amount}
      end)

    %TournamentFinished{
      tournament_id: tournament.id,
      prize_pool: prize_pool,
      payouts: payouts
    }
  end

  def execute(%__MODULE__{status: status}, %FinishTournament{}) when status != :active do
    {:error, :tournament_not_active}
  end

  # STATE MUTATORS

  def apply(%__MODULE__{}, %TournamentCreated{} = event) do
    %__MODULE__{
      id: event.id,
      creator_id: event.creator_id,
      status: event.status,
      speed: event.speed,
      buy_in: event.buy_in,
      starting_stack: event.starting_stack,
      table_type: event.table_type,
      max_players: event.max_players,
      current_level: 1,
      registered_players: [],
      busted_players: []
    }
  end

  def apply(%__MODULE__{} = state, %PlayerRegistered{player_id: player_id}) do
    %__MODULE__{state | registered_players: state.registered_players ++ [player_id]}
  end

  def apply(%__MODULE__{} = state, %TournamentStarted{}) do
    %__MODULE__{state | status: :active}
  end

  def apply(%__MODULE__{} = state, %BlindLevelAdvanced{level: level}) do
    %__MODULE__{state | current_level: level}
  end

  def apply(%__MODULE__{} = state, %TournamentTableCreated{table_id: table_id}) do
    %__MODULE__{state | table_ids: state.table_ids ++ [table_id]}
  end

  def apply(%__MODULE__{} = state, %TournamentPlayerBusted{player_id: player_id}) do
    %__MODULE__{state | busted_players: state.busted_players ++ [player_id]}
  end

  def apply(%__MODULE__{} = state, %TournamentFinished{}) do
    %__MODULE__{state | status: :finished}
  end

  # PRIVATE

  defp build_final_placements(winner, busted_players) do
    total = length(busted_players) + 1

    busted_placements =
      busted_players
      |> Enum.with_index()
      |> Enum.map(fn {player_id, idx} ->
        %{player_id: player_id, position: total - idx}
      end)

    [%{player_id: winner, position: 1} | busted_placements]
  end
end
