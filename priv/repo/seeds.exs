# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
Application.ensure_all_started(:poker)

IO.puts("Starting poker database seeding...")

# --- Users ---

users_attrs = [
  %{email: "test1@test.com", password: "testpassword123"},
  %{email: "test2@test.com", password: "testpassword123"}
]

users =
  Enum.map(users_attrs, fn attrs ->
    case Poker.Accounts.get_user_by_email(attrs.email) do
      nil ->
        {:ok, user} = Poker.Accounts.register_user(attrs)
        {:ok, user} = Poker.Accounts.confirm_user(user)
        user

      user ->
        IO.puts("  User #{user.email} already exists, ensuring wallet")
        Poker.Wallet.create_wallet(user.id, initial_balance: 10_000)
        user
    end
  end)

[user1, _user2] = users
IO.puts("Users ready")

# --- Cash Game (empty, no players) ---

{:ok, %{cash_game_id: cash_game_id, table_id: cash_table_id}} =
  Poker.CashGames.create_cash_game(user1.id, %{
    small_blind: 10,
    big_blind: 20,
    min_buyin: 500,
    max_buyin: 2000,
    table_type: :six_max
  })

IO.puts("Cash game created (ID: #{cash_game_id}, Table: #{cash_table_id})")

# --- Sit & Go Tournament (heads up) ---

{:ok, %{tournament_id: tournament_id}} =
  Poker.Tournaments.create_tournament(user1.id, %{
    speed: :regular,
    buy_in: 100,
    table_type: :two_max
  })

IO.puts("Tournament created (ID: #{tournament_id})")

# --- Summary ---

IO.puts("\nSeeding complete!")
IO.puts("  Accounts: test1@test.com / test2@test.com (password: testpassword123)")
IO.puts("  Cash game: #{cash_game_id} (6-max, 10/20 blinds, no players)")
IO.puts("  Tournament: #{tournament_id} (heads-up Sit & Go, 100 buy-in, registering)")
