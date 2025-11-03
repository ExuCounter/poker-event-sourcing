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
end
