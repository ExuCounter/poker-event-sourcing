defmodule Poker.Accounts.Schemas.User do
  use Poker, :schema

  schema "users" do
    field :email, :string
    field :nickname, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :google_id, :string
    field :confirmed_at, :utc_datetime
    field :authenticated_at, :utc_datetime, virtual: true
    field :role, Ecto.Enum, values: [:player, :admin], default: :player

    timestamps(type: :utc_datetime)
  end

  @doc """
  A user changeset for registering via an OAuth provider (Google).

  Casts email and google_id, validates both for uniqueness, and reuses the
  default email/nickname validations from `email_changeset/3`.
  """
  def google_register_changeset(user, attrs) do
    user
    |> cast(attrs, [:google_id])
    |> validate_required([:google_id])
    |> unsafe_validate_unique(:google_id, Poker.Repo)
    |> unique_constraint(:google_id)
    |> email_changeset(attrs)
  end

  @doc """
  A user changeset for registering or changing the email.

  It requires the email to change otherwise an error is added.

  ## Options

    * `:validate_unique` - Set to false if you don't want to validate the
      uniqueness of the email, useful when displaying live validations.
      Defaults to `true`.
  """
  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :role, :nickname])
    |> validate_required([:role])
    |> validate_email(opts)
    |> maybe_set_default_nickname()
    |> maybe_validate_nickname(opts)
  end

  defp maybe_set_default_nickname(changeset) do
    if get_field(changeset, :nickname) do
      changeset
    else
      put_change(changeset, :nickname, "player_#{:rand.uniform(999_999)}")
    end
  end

  defp maybe_validate_nickname(changeset, opts) do
    if get_change(changeset, :nickname) do
      changeset
      |> validate_length(:nickname, min: 3, max: 20)
      |> validate_format(:nickname, ~r/^[a-zA-Z0-9_]+$/,
        message: "can only contain letters, numbers, and underscores"
      )
      |> maybe_validate_unique_nickname(opts)
    else
      changeset
    end
  end

  @doc """
  A user changeset for updating the nickname.

  ## Options

    * `:validate_unique` - Set to false if you don't want to validate the
      uniqueness of the nickname, useful when displaying live validations.
      Defaults to `true`.
  """
  def nickname_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:nickname])
    |> validate_required([:nickname])
    |> validate_length(:nickname, min: 3, max: 20)
    |> validate_format(:nickname, ~r/^[a-zA-Z0-9_]+$/,
      message: "can only contain letters, numbers, and underscores"
    )
    |> maybe_validate_unique_nickname(opts)
  end

  defp maybe_validate_unique_nickname(changeset, opts) do
    if Keyword.get(opts, :validate_unique, true) do
      changeset
      |> unsafe_validate_unique(:nickname, Poker.Repo)
      |> unique_constraint(:nickname)
    else
      changeset
    end
  end

  defp validate_email(changeset, opts) do
    changeset =
      changeset
      |> validate_required([:email])
      |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
        message: "must have the @ sign and no spaces"
      )
      |> validate_length(:email, max: 160)

    if Keyword.get(opts, :validate_unique, true) do
      changeset
      |> unsafe_validate_unique(:email, Poker.Repo)
      |> unique_constraint(:email)
      |> validate_email_changed()
    else
      changeset
    end
  end

  defp validate_email_changed(changeset) do
    if get_field(changeset, :email) && get_change(changeset, :email) == nil do
      add_error(changeset, :email, "did not change")
    else
      changeset
    end
  end

  @doc """
  A user changeset for changing the password.

  It is important to validate the length of the password, as long passwords may
  be very expensive to hash for certain algorithms.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.
  """
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 12, max: 72)
    # Examples of additional password validation:
    # |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    # |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    # |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/, message: "at least one digit or punctuation character")
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      # If using Bcrypt, then further validate it is at most 72 bytes long
      |> validate_length(:password, max: 72, count: :bytes)
      # Hashing could be done with `Ecto.Changeset.prepare_changes/2`, but that
      # would keep the database transaction open longer and hurt performance.
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    now = DateTime.utc_now(:second)
    change(user, confirmed_at: now)
  end
end
