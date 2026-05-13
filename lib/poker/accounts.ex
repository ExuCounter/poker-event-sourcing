defmodule Poker.Accounts do
  import Ecto.Query
  alias Poker.Repo
  alias Poker.Accounts.Queries
  alias Poker.Accounts.Schemas.{User, UserToken}
  alias Poker.Accounts.UserNotifier

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by Google subject id.
  """
  def get_user_by_google_id(google_id) when is_binary(google_id) do
    Repo.get_by(User, google_id: google_id)
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if valid_password?(user, password), do: user
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc "Returns true if the user is an ephemeral guest account."
  def guest?(%User{is_guest: true}), do: true
  def guest?(%User{}), do: false

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    %User{}
    |> User.email_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Registers a user from a Google OAuth callback.

  Fails when the email or google_id is already taken (linking is intentionally
  strict — existing accounts must use their original sign-in method).

  On success the user is also confirmed, which provisions their wallet.
  """
  def register_with_google(%{google_id: google_id, email: email} = attrs)
      when is_binary(google_id) and is_binary(email) do
    Repo.transact(fn ->
      with {:ok, user} <- %User{} |> User.google_register_changeset(attrs) |> Repo.insert(),
           {:ok, user} <- confirm_user(user) do
        {:ok, user}
      end
    end)
  end

  @doc """
  Confirms an unconfirmed user: creates a wallet (for players) and sets confirmed_at.
  Returns {:ok, user} or {:error, reason}.
  """
  def confirm_user(%User{confirmed_at: nil} = user) do
    with :ok <- create_wallet_for_player(user) do
      user
      |> User.confirm_changeset()
      |> Repo.update()
    end
  end

  @doc """
  Creates a guest user: synthetic email, auto-generated nickname, confirmed
  immediately, wallet seeded with the guest starting balance. Guests are
  ephemeral (cleaned up by `Poker.Accounts.GuestCleanupWorker` after a few
  days of inactivity) and can later be upgraded into a real user via
  `upgrade_guest/2` while preserving their wallet and history.
  """
  def register_guest do
    id = Ecto.UUID.generate()
    now = DateTime.utc_now(:second)

    attrs = %{
      email: "guest-#{id}@guests.local",
      nickname: "guest_#{:rand.uniform(999_999)}",
      role: :player,
      confirmed_at: now,
      last_active_at: now
    }

    # Wallet seeding (Commanded dispatch with strong consistency) must run
    # outside a Repo transaction so the projector can checkout its own
    # connection. The user row is fully populated at insert time so there
    # is no follow-up update that could leave the account half-built.
    with {:ok, user} <- attrs |> User.guest_changeset() |> Repo.insert(),
         :ok <- create_wallet_for_player(user) do
      {:ok, user}
    end
  end

  @doc """
  Returns a changeset for the guest-upgrade form (live validation). Skips
  uniqueness and password hashing — those run only at submit time.
  """
  def change_guest_upgrade(%User{} = user, attrs \\ %{}) do
    User.upgrade_changeset(user, attrs, validate_unique: false, hash_password: false)
  end

  @doc """
  Upgrades a guest into a registered user by attaching a real email + password.
  The user UUID, wallet, and game history are preserved.
  """
  def upgrade_guest(%User{is_guest: true} = user, attrs) do
    user
    |> User.upgrade_changeset(attrs)
    |> Repo.update()
  end

  def upgrade_guest(%User{}, _attrs), do: {:error, :not_a_guest}

  @doc """
  Deletes a guest user record. Used on guest logout (immediate cleanup) and
  by the daily cleanup worker for inactive guests.
  """
  def delete_guest_user(%User{is_guest: true} = user), do: Repo.delete(user)
  def delete_guest_user(%User{}), do: {:error, :not_a_guest}

  @doc """
  Bumps `last_active_at` for the user. Throttled to one write per minute so
  busy LiveView mounts don't pile up updates.
  """
  def touch_last_active(%User{} = user) do
    now = DateTime.utc_now(:second)

    if needs_last_active_bump?(user, now) do
      Queries.by_id(user.id) |> Repo.update_all(set: [last_active_at: now])
    end

    :ok
  end

  defp needs_last_active_bump?(%User{last_active_at: nil}, _now), do: true

  defp needs_last_active_bump?(%User{last_active_at: ts}, now),
    do: DateTime.diff(now, ts, :minute) >= 1

  @doc """
  Deletes guest users that haven't been seen for `older_than_days` days.
  Returns the count of deleted users.
  """
  def delete_inactive_guests(older_than_days \\ 3) do
    cutoff = DateTime.utc_now(:second) |> DateTime.add(-older_than_days, :day)

    {count, _} =
      Queries.guests()
      |> Queries.inactive_since(cutoff)
      |> Repo.delete_all()

    count
  end

  @doc """
  Returns a changeset for the onboarding form (live validation).
  """
  def change_user_onboarding(user, attrs \\ %{}) do
    User.onboarding_changeset(user, attrs)
  end

  @doc """
  Returns a changeset for the nickname form (live validation).
  """
  def change_user_nickname(user, attrs \\ %{}, opts \\ []) do
    User.nickname_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user nickname.
  """
  def update_user_nickname(%User{} = user, attrs) do
    user
    |> User.nickname_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Persists onboarding form values and stamps `onboarded_at`.
  """
  def complete_onboarding(%User{} = user, attrs) do
    user
    |> User.onboarding_changeset(attrs)
    |> Repo.update()
  end

  ## Settings

  @doc """
  Checks whether the user is in sudo mode.

  The user is in sudo mode when the last authentication was done no further
  than 20 minutes ago. The limit can be given as second argument in minutes.
  """
  def sudo_mode?(user, minutes \\ -20)

  def sudo_mode?(%User{authenticated_at: ts}, minutes) when is_struct(ts, DateTime) do
    DateTime.after?(ts, DateTime.utc_now() |> DateTime.add(minutes, :minute))
  end

  def sudo_mode?(_user, _minutes), do: false

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  See `Poker.Accounts.User.email_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}, opts \\ []) do
    User.email_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    Repo.transact(fn ->
      with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
           %UserToken{sent_to: email} <- Repo.one(query),
           {:ok, user} <- Repo.update(User.email_changeset(user, %{email: email})),
           {_count, _result} <-
             Repo.delete_all(from(UserToken, where: [user_id: ^user.id, context: ^context])) do
        {:ok, user}
      else
        _ -> {:error, :transaction_aborted}
      end
    end)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  See `Poker.Accounts.User.password_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}, opts \\ []) do
    User.password_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user password.

  Returns a tuple with the updated user, as well as a list of expired tokens.

  ## Examples

      iex> update_user_password(user, %{password: ...})
      {:ok, {%User{}, [...]}}

      iex> update_user_password(user, %{password: "too short"})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, attrs) do
    user
    |> User.password_changeset(attrs)
    |> update_user_and_delete_all_tokens()
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.

  If the token is valid `{user, token_inserted_at}` is returned, otherwise `nil` is returned.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Gets the user with the given magic link token.
  """
  def get_user_by_magic_link_token(token) do
    with {:ok, query} <- UserToken.verify_magic_link_token_query(token),
         {user, _token} <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Logs the user in by magic link.

  There are three cases to consider:

  1. The user has already confirmed their email. They are logged in
     and the magic link is expired.

  2. The user has not confirmed their email and no password is set.
     In this case, the user gets confirmed, logged in, and all tokens -
     including session ones - are expired. In theory, no other tokens
     exist but we delete all of them for best security practices.

  3. The user has not confirmed their email but a password is set.
     This cannot happen in the default implementation but may be the
     source of security pitfalls. See the "Mixing magic link and password registration" section of
     `mix help phx.gen.auth`.
  """
  def login_user_by_magic_link(token) do
    {:ok, query} = UserToken.verify_magic_link_token_query(token)

    case Repo.one(query) do
      # Prevent session fixation attacks by disallowing magic links for unconfirmed users with password
      {%User{confirmed_at: nil, hashed_password: hash}, _token} when not is_nil(hash) ->
        raise """
        magic link log in is not allowed for unconfirmed users with a password set!

        This cannot happen with the default implementation, which indicates that you
        might have adapted the code to a different use case. Please make sure to read the
        "Mixing magic link and password registration" section of `mix help phx.gen.auth`.
        """

      {%User{confirmed_at: nil} = user, _token} ->
        with {:ok, user} <- confirm_user(user) do
          tokens_to_expire = Repo.all_by(UserToken, user_id: user.id)

          Repo.delete_all(
            from(t in UserToken, where: t.id in ^Enum.map(tokens_to_expire, & &1.id))
          )

          {:ok, {user, tokens_to_expire}}
        end

      {user, token} ->
        Repo.delete!(token)
        {:ok, {user, []}}

      nil ->
        {:error, :not_found}
    end
  end

  @doc ~S"""
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_user_update_email_instructions(user, current_email, &url(~p"/users/settings/confirm-email/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_update_email_instructions(
        %User{} = user,
        current_email,
        update_email_url_fun
      )
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} =
      UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Delivers the magic link login instructions to the given user.
  """
  def deliver_login_instructions(%User{} = user, magic_link_url_fun)
      when is_function(magic_link_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "login")
    Repo.insert!(user_token)
    UserNotifier.deliver_login_instructions(user, magic_link_url_fun.(encoded_token))
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(from(UserToken, where: [token: ^token, context: "session"]))
    :ok
  end

  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Bcrypt.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end

  ## Wallet

  @user_initial_balance 25_000
  @guest_initial_balance 10_000

  defp create_wallet_for_player(%User{role: :player, is_guest: is_guest, id: player_id}) do
    balance = if is_guest, do: @guest_initial_balance, else: @user_initial_balance

    case Poker.Wallet.create_wallet(player_id, initial_balance: balance) do
      :ok -> :ok
      {:error, :wallet_already_exists} -> :ok
      error -> error
    end
  end

  defp create_wallet_for_player(_user), do: :ok

  ## Token helper

  defp update_user_and_delete_all_tokens(changeset) do
    Repo.transact(fn ->
      with {:ok, user} <- Repo.update(changeset) do
        tokens_to_expire = Repo.all_by(UserToken, user_id: user.id)

        Repo.delete_all(from(t in UserToken, where: t.id in ^Enum.map(tokens_to_expire, & &1.id)))

        {:ok, {user, tokens_to_expire}}
      end
    end)
  end
end
