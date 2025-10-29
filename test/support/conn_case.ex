defmodule PokerWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use PokerWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      use SeedFactory.Test, schema: PokerWeb.SeedFactorySchema
      # The default endpoint for testing
      @endpoint PokerWeb.Endpoint

      use PokerWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import PokerWeb.ConnCase
    end
  end

  setup tags do
    Poker.DataCase.setup_sandbox(tags)

    SeedFactory.exec(tags, :build_conn)
  end

  @doc """
  Setup helper that registers and logs in users.

      setup :register_and_log_in_user

  It stores an updated connection and a registered user in the
  test context.
  """
  def register_and_log_in_user(%{conn: conn} = context) do
    user = Poker.AccountsFixtures.user_fixture()
    scope = Poker.Accounts.Scope.for_user(user)

    opts =
      context
      |> Map.take([:token_authenticated_at])
      |> Enum.into([])

    %{conn: log_in_user(conn, user, opts), user: user, scope: scope}
  end

  @doc """
  Logs the given `user` into the `conn`.

  It returns an updated `conn`.
  """
  def log_in_user(conn, user, opts \\ []) do
    token = Poker.Accounts.generate_user_session_token(user)

    maybe_set_token_authenticated_at(token, opts[:token_authenticated_at])

    conn |> Phoenix.ConnTest.init_test_session(%{user_token: token})
  end

  defp maybe_set_token_authenticated_at(_token, nil), do: nil

  defp maybe_set_token_authenticated_at(token, authenticated_at) do
    Poker.AccountsFixtures.override_token_authenticated_at(token, authenticated_at)
  end

  @doc """
  Generates a magic link token for a user.

  Returns a tuple of {encoded_token, hashed_token}.
  """
  def generate_user_magic_link_token(user) do
    {encoded_token, user_token} =
      Poker.Accounts.Schemas.UserToken.build_email_token(user, "login")

    Poker.Repo.insert!(user_token)
    {encoded_token, user_token.token}
  end
end
