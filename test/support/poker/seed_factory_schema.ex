defmodule Poker.SeedFactorySchema do
  use SeedFactory.Schema

  command :create_user do
    param(:email, generate: &Faker.Internet.email/0)

    resolve(fn args ->
      {:ok, user} = Poker.Accounts.register_user(%{email: args.email})
      {:ok, %{user: user}}
    end)

    produce(:user)
  end

  command :set_user_password do
    param(:user, entity: :user)
    param(:password, generate: fn -> "valid_user_password" end)

    resolve(fn args ->
      {:ok, {user, _expired_tokens}} =
        Poker.Accounts.update_user_password(args.user, %{password: args.password})

      {:ok, %{user: user}}
    end)

    update(:user)
  end

  command :confirm_user do
    param(:user, entity: :user)

    resolve(fn args ->
      user = args.user

      token =
        extract_user_token(fn url ->
          Poker.Accounts.deliver_login_instructions(user, url)
        end)

      {:ok, {user, _expired_tokens}} = Poker.Accounts.login_user_by_magic_link(token)
      {:ok, %{user: user}}
    end)

    update(:user)
  end

  trait :confirmed, :user do
    exec(:confirm_user)
  end

  defp extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end
end
