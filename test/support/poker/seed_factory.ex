defmodule Poker.SeedFactorySchema do
  use SeedFactory.Schema

  command :create_player do
    param(:email, generate: &Faker.Internet.email/0)

    resolve(fn args ->
      {:ok, player} = Poker.Accounts.register_player(%{email: args.email})
      {:ok, %{player: player}}
    end)

    produce(:player)
  end

  command :create_table do
    param(:player, entity: :player)

    param(:settings,
      value: %{
        small_blind: 10,
        big_blind: 20,
        starting_stack: 1000,
        timeout_seconds: 90
      }
    )

    resolve(fn args ->
      {:ok, table} = Poker.Tables.create_table(args.player, args.settings)
      {:ok, %{table: table}}
    end)

    produce(:table)
  end
end
