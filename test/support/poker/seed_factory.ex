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

  def get_table_positions(table) do
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

  defp table_with_positions(table_id) do
    table = aggregate_state(:table, table_id)
    positions = get_table_positions(table)
    %{table: table, positions: positions}
  end

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

  command :create_table do
    param(:player, entity: :player)
    param(:type, value: :six_max)
    param(:subscribe_to_pub_sub?, value: false)

    param(:settings,
      value: %{
        small_blind: 10,
        big_blind: 20,
        starting_stack: 1000,
        timeout_seconds: 90
      }
    )

    resolve(fn args ->
      settings = Map.put(args.settings, :table_type, args.type)

      {:ok, %{table_id: table_id}} = Poker.Tables.create_table(args.player.id, settings)

      table = aggregate_state(:table, table_id)

      {:ok, %{table: table}}
    end)

    produce(:table)
  end

  command :add_participants do
    param(:table, entity: :table)
    param(:players, value: [])
    param(:generate_players)

    resolve(fn args ->
      players =
        if args.generate_players do
          for _ <- 1..args.generate_players do
            {:ok, player} =
              Poker.Accounts.register_user(%{
                email: Faker.Internet.email(),
                role: :player,
                nickname: "player_#{:rand.uniform(999_999)}"
              })

            player
          end
        else
          args.players
        end

      participants =
        players
        |> Enum.map(fn
          {player, attrs} -> {player, attrs}
          player -> {player, %{}}
        end)
        |> Enum.map(fn {player, attrs} ->
          {:ok, _participant_id} = Poker.Tables.join_participant(args.table.id, player.id, attrs)
        end)

      table = aggregate_state(:table, args.table.id)

      {:ok, %{table: table}}
    end)

    update(:table)
  end

  command :start_table do
    param(:table, entity: :table)

    resolve(fn args ->
      :ok = Poker.Tables.start_table(args.table.id)
      {:ok, table_with_positions(args.table.id)}
    end)

    update(:table)
    produce(:positions)
  end

  command :raise_hand do
    param(:table, entity: :table)
    param(:amount)

    resolve(fn args ->
      acting_player_id = get_acting_player_id(args.table)

      :ok =
        Poker.Tables.raise_hand(
          args.table.id,
          acting_player_id,
          args.amount
        )

      {:ok, table_with_positions(args.table.id)}
    end)

    update(:table)
    update(:positions)
  end

  command :call_hand do
    param(:table, entity: :table)

    resolve(fn args ->
      acting_player_id = get_acting_player_id(args.table)
      :ok = Poker.Tables.call_hand(args.table.id, acting_player_id)
      {:ok, table_with_positions(args.table.id)}
    end)

    update(:table)
    update(:positions)
  end

  command :check_hand do
    param(:table, entity: :table)

    resolve(fn args ->
      acting_player_id = get_acting_player_id(args.table)
      :ok = Poker.Tables.check_hand(args.table.id, acting_player_id)
      {:ok, table_with_positions(args.table.id)}
    end)

    update(:table)
    update(:positions)
  end

  command :all_in_hand do
    param(:table, entity: :table)

    resolve(fn args ->
      acting_player_id = get_acting_player_id(args.table)
      :ok = Poker.Tables.all_in_hand(args.table.id, acting_player_id)
      {:ok, table_with_positions(args.table.id)}
    end)

    update(:table)
    update(:positions)
  end

  command :fold_hand do
    param(:table, entity: :table)

    resolve(fn args ->
      acting_player_id = get_acting_player_id(args.table)
      :ok = Poker.Tables.fold_hand(args.table.id, acting_player_id)
      {:ok, table_with_positions(args.table.id)}
    end)

    update(:table)
    update(:positions)
  end

  command :advance_round do
    param(:table, entity: :table)

    resolve(fn args ->
      args.table.participants
      |> Enum.each(fn _participant ->
        table = aggregate_state(:table, args.table.id)
        acting_player_id = get_acting_player_id(table)
        :ok = Poker.Tables.call_hand(args.table.id, acting_player_id)
      end)

      {:ok, table_with_positions(args.table.id)}
    end)

    update(:table)
    update(:positions)
  end

  command :start_runout do
    param(:table, entity: :table)

    resolve(fn args ->
      args.table.participants
      |> Enum.each(fn _ ->
        table = aggregate_state(:table, args.table.id)
        acting_player_id = get_acting_player_id(table)
        :ok = Poker.Tables.all_in_hand(args.table.id, acting_player_id)
      end)

      {:ok, table_with_positions(args.table.id)}
    end)

    update(:table)
    update(:positions)
  end

  command :sit_out do
    param(:table, entity: :table)

    resolve(fn args ->
      acting_player_id = get_acting_player_id(args.table)
      :ok = Poker.Tables.sit_out_participant(args.table.id, acting_player_id)
      {:ok, table_with_positions(args.table.id)}
    end)

    update(:table)
    update(:positions)
  end

  command :sit_in do
    param(:table, entity: :table)

    resolve(fn args ->
      acting_player_id = get_acting_player_id(args.table)
      :ok = Poker.Tables.sit_in_participant(args.table.id, acting_player_id)
      {:ok, table_with_positions(args.table.id)}
    end)

    update(:table)
    update(:positions)
  end

  def get_acting_player_id(table) do
    table.participants
    |> Enum.find(&(&1.id == table.round.participant_to_act_id))
    |> then(& &1.player_id)
  end
end
