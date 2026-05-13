defmodule Poker.SeedFactorySchema do
  use SeedFactory.Schema

  def aggregate_state(:table, table_id) do
    Poker.TestSupport.ProcessManagerAwaiter.wait_to_settle()

    Commanded.Aggregates.Aggregate.aggregate_state(
      Poker.App,
      Poker.Tables.Aggregates.Table,
      "table-" <> table_id
    )
  end

  def aggregate_state(:cash_game, cash_game_id) do
    Poker.TestSupport.ProcessManagerAwaiter.wait_to_settle()

    Commanded.Aggregates.Aggregate.aggregate_state(
      Poker.App,
      Poker.CashGames.Aggregates.CashGame,
      "cash-game-" <> cash_game_id
    )
  end

  def aggregate_state(:tournament, tournament_id) do
    Poker.TestSupport.ProcessManagerAwaiter.wait_to_settle()

    Commanded.Aggregates.Aggregate.aggregate_state(
      Poker.App,
      Poker.Tournaments.Aggregates.Tournament,
      "tournament-" <> tournament_id
    )
  end

  def positions(table) do
    table.participant_hands
    |> Enum.map(fn hand ->
      {hand.position,
       %{
         hand: hand,
         participant: Enum.find(table.participants, &(&1.id == hand.participant_id))
       }}
    end)
    |> Enum.into(%{})
  end

  defp resolve_acting_player(table, position) do
    acting_participant =
      Enum.find(table.participants, &(&1.id == table.round.participant_to_act_id))

    acting_hand =
      Enum.find(table.participant_hands, &(&1.participant_id == acting_participant.id))

    if acting_hand.position != position do
      raise "Expected #{inspect(position)} to act, but #{inspect(acting_hand.position)} is acting"
    end

    acting_participant.player_id
  end

  # Player commands & traits

  command :create_player do
    param(:email, generate: &Faker.Internet.email/0)
    param(:nickname, generate: fn -> "player_#{:rand.uniform(999_999)}" end)

    resolve(fn args ->
      {:ok, user} =
        Poker.Accounts.register_user(%{email: args.email, role: :player, nickname: args.nickname})

      {:ok, %{player: user}}
    end)

    produce(:player)
  end

  command :activate_player do
    param(:player, entity: :player, with_traits: [:pending])

    resolve(fn args ->
      {:ok, user} = Poker.Accounts.confirm_user(args.player)
      {:ok, wallet} = Poker.Wallet.get_wallet(user.id)

      {:ok, %{player: user, wallet: wallet}}
    end)

    update(:player)
    produce(:wallet)
  end

  trait :pending, :player do
    exec(:create_player)
  end

  trait :active, :player do
    from(:pending)
    exec(:activate_player)
  end

  # Cash game commands

  command :create_cash_game do
    param(:player, entity: :player)

    param(:settings,
      value: %{
        small_blind: 10,
        big_blind: 20,
        min_buyin: 500,
        max_buyin: 1000,
        table_type: :six_max
      }
    )

    resolve(fn args ->
      {:ok, %{cash_game_id: cash_game_id, table_id: table_id}} =
        Poker.CashGames.create_cash_game(args.player.id, args.settings)

      cash_game = aggregate_state(:cash_game, cash_game_id)
      table = aggregate_state(:table, table_id)

      {:ok, %{cash_game: cash_game, table: table}}
    end)

    produce(:cash_game)
    produce(:table)
  end

  command :join_cash_game do
    param(:cash_game, entity: :cash_game)
    param(:table, entity: :table)
    param(:player, entity: :player, with_traits: [:active])
    param(:buyin_amount)

    resolve(fn args ->
      buyin_amount = args.buyin_amount || args.cash_game.max_buyin

      {:ok, _participant_id} =
        Poker.CashGames.join_cash_game(args.cash_game.id, args.player.id, buyin_amount)

      cash_game = aggregate_state(:cash_game, args.cash_game.id)
      table = aggregate_state(:table, args.cash_game.table_id)

      {:ok, %{cash_game: cash_game, table: table}}
    end)

    update(:cash_game)
    update(:table)
  end

  command :fill_cash_game do
    param(:cash_game, entity: :cash_game)
    param(:table, entity: :table)
    param(:players_count)

    resolve(fn args ->
      max_players = max_players(args.cash_game.table_type)
      current = length(args.table.participants)
      count = args.players_count || max_players - current

      for _ <- 1..count do
        {:ok, player} =
          Poker.Accounts.register_user(%{
            email: Faker.Internet.email(),
            role: :player,
            nickname: "player_#{:rand.uniform(999_999)}"
          })

        {:ok, player} = Poker.Accounts.confirm_user(player)

        {:ok, _participant_id} =
          Poker.CashGames.join_cash_game(args.cash_game.id, player.id, args.cash_game.max_buyin)
      end

      cash_game = aggregate_state(:cash_game, args.cash_game.id)
      table = aggregate_state(:table, args.cash_game.table_id)

      {:ok, %{cash_game: cash_game, table: table}}
    end)

    update(:cash_game)
    update(:table)
  end

  defp max_players(:two_max), do: 2
  defp max_players(:three_max), do: 3
  defp max_players(:four_max), do: 4
  defp max_players(:six_max), do: 6

  # Tournament commands

  command :create_tournament do
    param(:player, entity: :player)

    param(:settings,
      value: %{
        speed: :hyper_turbo,
        buy_in: 100,
        table_type: :six_max
      }
    )

    resolve(fn args ->
      {:ok, %{tournament_id: tournament_id}} =
        Poker.Tournaments.create_tournament(args.player.id, args.settings)

      tournament = aggregate_state(:tournament, tournament_id)

      {:ok, %{tournament: tournament}}
    end)

    produce(:tournament)
  end

  command :register_player do
    param(:tournament, entity: :tournament)
    param(:player, entity: :player, with_traits: [:active])

    resolve(fn args ->
      :ok = Poker.Tournaments.register_player(args.tournament.id, args.player.id)

      tournament = aggregate_state(:tournament, args.tournament.id)

      {:ok, %{tournament: tournament}}
    end)

    update(:tournament)
  end

  command :fill_tournament do
    param(:tournament, entity: :tournament)

    resolve(fn args ->
      remaining = args.tournament.max_players - length(args.tournament.registered_players)

      for _ <- 1..remaining do
        {:ok, player} =
          Poker.Accounts.register_user(%{
            email: Faker.Internet.email(),
            role: :player,
            nickname: "player_#{:rand.uniform(999_999)}"
          })

        {:ok, player} = Poker.Accounts.confirm_user(player)
        :ok = Poker.Tournaments.register_player(args.tournament.id, player.id)
      end

      tournament = aggregate_state(:tournament, args.tournament.id)

      table_id = List.first(tournament.table_ids)
      table = aggregate_state(:table, table_id)

      {:ok, %{tournament: tournament, table: table}}
    end)

    update(:tournament)
    produce(:table)
  end

  # Hand action commands — position is required, table is an entity reference

  command :raise_hand do
    param(:table, entity: :table)
    param(:position)
    param(:amount)

    resolve(fn args ->
      acting_player_id = resolve_acting_player(args.table, args.position)

      :ok =
        Poker.Tables.raise_hand(
          args.table.id,
          acting_player_id,
          args.amount
        )

      table = aggregate_state(:table, args.table.id)
      {:ok, %{table: table}}
    end)

    update(:table)
  end

  command :call_hand do
    param(:table, entity: :table)
    param(:position)

    resolve(fn args ->
      acting_player_id = resolve_acting_player(args.table, args.position)
      :ok = Poker.Tables.call_hand(args.table.id, acting_player_id)
      table = aggregate_state(:table, args.table.id)
      {:ok, %{table: table}}
    end)

    update(:table)
  end

  command :check_hand do
    param(:table, entity: :table)
    param(:position)

    resolve(fn args ->
      acting_player_id = resolve_acting_player(args.table, args.position)
      :ok = Poker.Tables.check_hand(args.table.id, acting_player_id)
      table = aggregate_state(:table, args.table.id)
      {:ok, %{table: table}}
    end)

    update(:table)
  end

  command :all_in_hand do
    param(:table, entity: :table)
    param(:position)

    resolve(fn args ->
      acting_player_id = resolve_acting_player(args.table, args.position)
      :ok = Poker.Tables.all_in_hand(args.table.id, acting_player_id)
      table = aggregate_state(:table, args.table.id)
      {:ok, %{table: table}}
    end)

    update(:table)
  end

  command :fold_hand do
    param(:table, entity: :table)
    param(:position)

    resolve(fn args ->
      acting_player_id = resolve_acting_player(args.table, args.position)
      :ok = Poker.Tables.fold_hand(args.table.id, acting_player_id)
      table = aggregate_state(:table, args.table.id)
      {:ok, %{table: table}}
    end)

    update(:table)
  end

  # Utility commands — iterate all players, no position needed

  command :advance_round do
    param(:table, entity: :table)

    resolve(fn args ->
      args.table.participants
      |> Enum.each(fn _participant ->
        table = aggregate_state(:table, args.table.id)

        acting_participant =
          Enum.find(table.participants, &(&1.id == table.round.participant_to_act_id))

        :ok = Poker.Tables.call_hand(args.table.id, acting_participant.player_id)
      end)

      table = aggregate_state(:table, args.table.id)
      {:ok, %{table: table}}
    end)

    update(:table)
  end

  command :start_runout do
    param(:table, entity: :table)

    resolve(fn args ->
      args.table.participants
      |> Enum.each(fn _ ->
        table = aggregate_state(:table, args.table.id)

        acting_participant =
          Enum.find(table.participants, &(&1.id == table.round.participant_to_act_id))

        :ok = Poker.Tables.all_in_hand(args.table.id, acting_participant.player_id)
      end)

      table = aggregate_state(:table, args.table.id)
      {:ok, %{table: table}}
    end)

    update(:table)
  end

  command :sit_out do
    param(:table, entity: :table)
    param(:position)

    resolve(fn args ->
      player_id = resolve_acting_player(args.table, args.position)
      :ok = Poker.Tables.sit_out_participant(args.table.id, player_id)
      table = aggregate_state(:table, args.table.id)
      {:ok, %{table: table}}
    end)

    update(:table)
  end

  command :sit_in do
    param(:table, entity: :table)
    param(:position)

    resolve(fn args ->
      player_id = resolve_acting_player(args.table, args.position)
      :ok = Poker.Tables.sit_in_participant(args.table.id, player_id)
      table = aggregate_state(:table, args.table.id)
      {:ok, %{table: table}}
    end)

    update(:table)
  end
end
