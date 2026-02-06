# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Or with test environment (needed for Faker):
#
#     MIX_ENV=test mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Poker.Repo.insert!(%Poker.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.
#
Application.ensure_all_started(:poker)

IO.inspect(Process.whereis(Poker.App), label: "App process")
IO.inspect(Process.whereis(Poker.EventStore), label: "EventStore process")

IO.puts("🎲 Starting poker database seeding...")

# Step 1: Create test users
IO.puts("👥 Creating 6 test users...")

# Primary test user (fixed email)
primary_user_attrs = %{email: "test@gmail.com", password: "testpassword123"}

# Generate additional users with Faker
additional_users_attrs =
  for _ <- 1..6 do
    %{
      email: Faker.Internet.email(),
      password: "testpassword123"
    }
  end

users_attrs = [primary_user_attrs | additional_users_attrs]

users =
  Enum.map(users_attrs, fn attrs ->
    case Poker.Accounts.get_user_by_email(attrs.email) do
      nil ->
        # User doesn't exist, create and confirm
        {:ok, user} = Poker.Accounts.register_user(attrs)

        user
        |> Poker.Accounts.Schemas.User.confirm_changeset()
        |> Poker.Repo.update!()

      user ->
        # User already exists, use it
        IO.puts("  ℹ User #{user.email} already exists, skipping creation")
        user
    end
  end)

IO.puts("✓ Users created and confirmed")

# Step 2: Create poker table
IO.puts("🃏 Creating poker table...")

[creator | _] = users

settings = %{
  small_blind: 10,
  big_blind: 20,
  starting_stack: 1000,
  timeout_seconds: 90,
  table_type: :six_max
}

{:ok, %{table_id: table_id}} = Poker.Tables.create_table(creator.id, settings)

IO.puts("✓ Table created (ID: #{table_id})")

# Step 3: Add remaining participants
IO.puts("👫 Adding participants to table...")

Enum.each(tl(users), fn user ->
  {:ok, _participant_id} = Poker.Tables.join_participant(table_id, user.id)
end)

IO.puts("✓ All 6 participants added")

# Step 4: Start the table
IO.puts("▶️  Starting table...")

:ok = Poker.Tables.start_table(table_id)

IO.puts("✓ Table started")

# Success summary
IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("✅ Seeding complete!")
IO.puts(String.duplicate("=", 60))
IO.puts("📧 Test accounts created:")
IO.puts("   • test@gmail.com (primary)")

Enum.drop(users, 1)
|> Enum.each(fn user ->
  IO.puts("   • #{user.email} (generated)")
end)

IO.puts("🔑 Password for all accounts: testpassword123")
IO.puts("🃏 Live table ID: #{table_id}")
IO.puts("💰 Starting stack: 1000 chips")
IO.puts("💵 Blinds: 10/20")
IO.puts(String.duplicate("=", 60) <> "\n")
