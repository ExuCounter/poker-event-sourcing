defmodule Poker.SeedFactorySchema do
  use SeedFactory.Schema
  import Commanded.Assertions.EventAssertions

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

  command :create_player do
    param(:email, generate: &Faker.Internet.email/0)

    resolve(fn args ->
      {:ok, user} = Poker.Accounts.register_user(%{email: args.email, role: :player})

      {:ok, %{player: user}}
    end)

    produce(:player)
  end

  command :create_table do
    param(:player, entity: :player)
    param(:type, value: :six_max)

    param(:settings,
      value: %{
        small_blind: 10,
        big_blind: 20,
        starting_stack: 1000,
        timeout_seconds: 90
      }
    )

    resolve(fn args ->
      settings = args.settings |> Map.put(:table_type, args.type)

      {:ok, %{table_id: table_id}} = Poker.Tables.create_table(args.player.id, settings)

      Poker.TableEvents.subscribe_to_table(table_id)

      aggregate_state = aggregate_state(:table, table_id)

      ExUnit.Callbacks.on_exit(fn ->
        Poker.TableEvents.unsubscribe_from_table(table_id)
      end)

      {:ok, %{table: aggregate_state}}
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
              Poker.Accounts.register_user(%{email: Faker.Internet.email(), role: :player})

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
      {:ok, _hand_id} = Poker.Tables.start_table(args.table.id)

      table = aggregate_state(:table, args.table.id)
      positions = get_table_positions(table)

      {:ok, %{table: table, positions: positions}}
    end)

    update(:table)
    produce(:positions)
  end

  command :raise_hand do
    param(:table, entity: :table)
    param(:amount)

    resolve(fn args ->
      :ok =
        Poker.Tables.raise_hand(
          args.table.id,
          args.table.round.participant_to_act_id,
          args.amount
        )

      table = aggregate_state(:table, args.table.id)
      positions = get_table_positions(table)

      {:ok, %{table: table, positions: positions}}
    end)

    update(:table)
    update(:positions)
  end

  command :call_hand do
    param(:table, entity: :table)

    resolve(fn args ->
      :ok = Poker.Tables.call_hand(args.table.id, args.table.round.participant_to_act_id)

      table = aggregate_state(:table, args.table.id)
      positions = get_table_positions(table)

      {:ok, %{table: table, positions: positions}}
    end)

    update(:table)
    update(:positions)
  end

  command :all_in_hand do
    param(:table, entity: :table)

    resolve(fn args ->
      :ok = Poker.Tables.all_in_hand(args.table.id, args.table.round.participant_to_act_id)

      table = aggregate_state(:table, args.table.id)
      positions = get_table_positions(table)

      {:ok, %{table: table, positions: positions}}
    end)

    update(:table)
    update(:positions)
  end

  command :fold_hand do
    param(:table, entity: :table)

    resolve(fn args ->
      :ok = Poker.Tables.fold_hand(args.table.id, args.table.round.participant_to_act_id)

      table = aggregate_state(:table, args.table.id)
      positions = get_table_positions(table)

      {:ok, %{table: table, positions: positions}}
    end)

    update(:table)
    update(:positions)
  end

  command :advance_round do
    param(:table, entity: :table)

    resolve(fn args ->
      args.table.participants
      |> Enum.each(fn _participant ->
        %{
          round: %{
            participant_to_act_id: participant_to_act_id
          }
        } = aggregate_state(:table, args.table.id)

        :ok = Poker.Tables.call_hand(args.table.id, participant_to_act_id)
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
      |> Enum.each(fn _participant ->
        %{
          round: %{
            participant_to_act_id: participant_to_act_id
          }
        } = aggregate_state(:table, args.table.id)

        :ok = Poker.Tables.all_in_hand(args.table.id, participant_to_act_id)
      end)

      table = aggregate_state(:table, args.table.id)

      {:ok, %{table: table}}
    end)

    update(:table)
  end
end
