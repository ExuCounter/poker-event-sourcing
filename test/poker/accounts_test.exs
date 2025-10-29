defmodule Poker.AccountsTest do
  use Poker.DataCase

  alias Poker.Accounts
  alias Poker.Accounts.Schemas.{User, UserToken}

  describe "get_user_by_email/1" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email("unknown@example.com")
    end

    test "returns the user if the email exists", ctx do
      ctx = ctx |> produce(:user)
      user = Accounts.get_user_by_email(ctx.user.email)

      assert user.id == ctx.user.id
    end
  end

  describe "get_user_by_email_and_password/2" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the user if the password is not valid", ctx do
      ctx = ctx |> produce(:user) |> exec(:set_user_password, password: "valid password")
      refute Accounts.get_user_by_email_and_password(ctx.user.email, "invalid")
    end

    test "returns the user if the email and password are valid", ctx do
      ctx = ctx |> produce(:user) |> exec(:set_user_password, password: "valid password")

      user = Accounts.get_user_by_email_and_password(ctx.user.email, "valid password")
      assert user.id == ctx.user.id
    end
  end

  describe "get_user!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_user!(-1)
      end
    end

    test "returns the user with the given id", ctx do
      ctx = ctx |> produce(user: [:confirmed])
      %{id: id} = ctx.user
      assert %User{id: ^id} = Accounts.get_user!(ctx.user.id)
    end
  end

  describe "register_user/1" do
    test "requires email to be set" do
      {:error, changeset} = Accounts.register_user(%{})

      assert %{email: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates email when given" do
      {:error, changeset} = Accounts.register_user(%{email: "not valid"})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum values for email for security" do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.register_user(%{email: too_long})
      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates email uniqueness", ctx do
      ctx = ctx |> produce(:user)
      email = ctx.user.email

      {:error, changeset} = Accounts.register_user(%{email: email})
      assert "has already been taken" in errors_on(changeset).email

      # Now try with the upper cased email too, to check that email case is ignored.
      {:error, changeset} = Accounts.register_user(%{email: String.upcase(email)})
      assert "has already been taken" in errors_on(changeset).email
    end

    test "registers users without password" do
      email = Faker.Internet.email()
      {:ok, user} = Accounts.register_user(%{email: email})
      assert user.email == email
      assert is_nil(user.hashed_password)
      assert is_nil(user.confirmed_at)
      assert is_nil(user.password)
    end
  end

  describe "sudo_mode?/2" do
    test "validates the authenticated_at time" do
      now = DateTime.utc_now()

      assert Accounts.sudo_mode?(%User{authenticated_at: DateTime.utc_now()})
      assert Accounts.sudo_mode?(%User{authenticated_at: DateTime.add(now, -19, :minute)})
      refute Accounts.sudo_mode?(%User{authenticated_at: DateTime.add(now, -21, :minute)})

      # minute override
      refute Accounts.sudo_mode?(
               %User{authenticated_at: DateTime.add(now, -11, :minute)},
               -10
             )

      # not authenticated
      refute Accounts.sudo_mode?(%User{})
    end
  end

  describe "change_user_email/3" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_email(%User{})
      assert changeset.required == [:email]
    end
  end

  describe "deliver_user_update_email_instructions/3" do
    test "sends token through notification", ctx do
      ctx = ctx |> produce(user: [:confirmed])

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_update_email_instructions(ctx.user, "current@example.com", url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == ctx.user.id
      assert user_token.sent_to == ctx.user.email
      assert user_token.context == "change:current@example.com"
    end
  end

  describe "update_user_email/2" do
    setup ctx do
      ctx = ctx |> produce(:user)
      email = Faker.Internet.email()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_update_email_instructions(
            %{ctx.user | email: email},
            ctx.user.email,
            url
          )
        end)

      Map.merge(ctx, %{token: token, email: email})
    end

    test "updates the email with a valid token", %{user: user, token: token, email: email} do
      assert {:ok, %{email: ^email}} = Accounts.update_user_email(user, token)
      changed_user = Repo.get!(User, user.id)
      assert changed_user.email != user.email
      assert changed_user.email == email
      refute Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email with invalid token", %{user: user} do
      assert Accounts.update_user_email(user, "oops") ==
               {:error, :transaction_aborted}

      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email if user email changed", %{user: user, token: token} do
      assert Accounts.update_user_email(%{user | email: "current@example.com"}, token) ==
               {:error, :transaction_aborted}

      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email if token expired", %{user: user, token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])

      assert Accounts.update_user_email(user, token) ==
               {:error, :transaction_aborted}

      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "change_user_password/3" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_password(%User{})
      assert changeset.required == [:password]
    end

    test "allows fields to be set" do
      changeset =
        Accounts.change_user_password(
          %User{},
          %{
            "password" => "new valid password"
          },
          hash_password: false
        )

      assert changeset.valid?
      assert get_change(changeset, :password) == "new valid password"
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "update_user_password/2" do
    setup ctx do
      ctx |> produce(user: [:confirmed])
    end

    test "validates password", %{user: user} do
      {:error, changeset} =
        Accounts.update_user_password(user, %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{user: user} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.update_user_password(user, %{password: too_long})

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "updates the password", %{user: user} do
      {:ok, {user, expired_tokens}} =
        Accounts.update_user_password(user, %{
          password: "new valid password"
        })

      assert expired_tokens == []
      assert is_nil(user.password)
      assert Accounts.get_user_by_email_and_password(user.email, "new valid password")
    end

    test "deletes all tokens for the given user", %{user: user} do
      _ = Accounts.generate_user_session_token(user)

      {:ok, {_, _}} =
        Accounts.update_user_password(user, %{
          password: "new valid password"
        })

      refute Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "generate_user_session_token/1" do
    test "generates a token", ctx do
      ctx1 = ctx |> produce(user: [:confirmed])
      token = Accounts.generate_user_session_token(ctx1.user)
      assert user_token = Repo.get_by(UserToken, token: token)
      assert user_token.context == "session"
      assert user_token.authenticated_at != nil

      # Creating the same token for another user should fail
      ctx2 = ctx |> produce(user: [:confirmed])

      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%UserToken{
          token: user_token.token,
          user_id: ctx2.user.id,
          context: "session"
        })
      end
    end

    test "duplicates the authenticated_at of given user in new token", ctx do
      ctx = ctx |> produce(user: [:confirmed])
      user = %{ctx.user | authenticated_at: DateTime.add(DateTime.utc_now(:second), -3600)}
      token = Accounts.generate_user_session_token(user)
      assert user_token = Repo.get_by(UserToken, token: token)
      assert user_token.authenticated_at == user.authenticated_at
      assert DateTime.compare(user_token.inserted_at, user.authenticated_at) == :gt
    end
  end

  describe "get_user_by_session_token/1" do
    test "returns user by token", ctx do
      ctx = ctx |> produce(user: [:confirmed])
      token = Accounts.generate_user_session_token(ctx.user)

      assert {session_user, token_inserted_at} = Accounts.get_user_by_session_token(token)
      assert session_user.id == ctx.user.id
      assert session_user.authenticated_at != nil
      assert token_inserted_at != nil
    end

    test "does not return user for invalid token" do
      refute Accounts.get_user_by_session_token("oops")
    end

    test "does not return user for expired token", ctx do
      ctx = ctx |> produce(user: [:confirmed])
      token = Accounts.generate_user_session_token(ctx.user)

      dt = ~N[2020-01-01 00:00:00]
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: dt, authenticated_at: dt])
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "get_user_by_magic_link_token/1" do
    test "returns user by token", ctx do
      ctx = ctx |> produce(user: [:confirmed])
      {encoded_token, _hashed_token} = generate_user_magic_link_token(ctx.user)

      assert session_user = Accounts.get_user_by_magic_link_token(encoded_token)
      assert session_user.id == ctx.user.id
    end

    test "does not return user for invalid token" do
      refute Accounts.get_user_by_magic_link_token("oops")
    end

    test "does not return user for expired token", ctx do
      ctx = ctx |> produce(user: [:confirmed])
      {encoded_token, _hashed_token} = generate_user_magic_link_token(ctx.user)

      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_user_by_magic_link_token(encoded_token)
    end
  end

  describe "login_user_by_magic_link/1" do
    test "confirms user and expires tokens", ctx do
      ctx = ctx |> produce(:user)
      refute ctx.user.confirmed_at
      {encoded_token, hashed_token} = generate_user_magic_link_token(ctx.user)

      assert {:ok, {user, [%{token: ^hashed_token}]}} =
               Accounts.login_user_by_magic_link(encoded_token)

      assert user.confirmed_at
    end

    test "returns user and (deleted) token for confirmed user", ctx do
      ctx = ctx |> produce(user: [:confirmed])
      assert ctx.user.confirmed_at
      {encoded_token, _hashed_token} = generate_user_magic_link_token(ctx.user)

      assert {:ok, {user, []}} = Accounts.login_user_by_magic_link(encoded_token)
      assert user.id == ctx.user.id
      # one time use only
      assert {:error, :not_found} = Accounts.login_user_by_magic_link(encoded_token)
    end

    test "raises when unconfirmed user has password set", ctx do
      ctx = ctx |> produce(:user)
      {encoded_token, _hashed_token} = generate_user_magic_link_token(ctx.user)
      {1, nil} = Repo.update_all(User, set: [hashed_password: "hashed"])

      assert_raise RuntimeError, ~r/magic link log in is not allowed/, fn ->
        Accounts.login_user_by_magic_link(encoded_token)
      end
    end
  end

  describe "delete_user_session_token/1" do
    test "deletes the token", ctx do
      ctx = ctx |> produce(user: [:confirmed])
      token = Accounts.generate_user_session_token(ctx.user)
      assert Accounts.delete_user_session_token(token) == :ok
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "deliver_login_instructions/2" do
    test "sends token through notification", ctx do
      ctx = ctx |> produce(:user)

      token =
        extract_user_token(fn url ->
          Accounts.deliver_login_instructions(ctx.user, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == ctx.user.id
      assert user_token.sent_to == ctx.user.email
      assert user_token.context == "login"
    end
  end

  describe "inspect/2 for the User module" do
    test "does not include password" do
      refute inspect(%User{password: "123456"}) =~ "password: \"123456\""
    end
  end

  defp extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end
end
