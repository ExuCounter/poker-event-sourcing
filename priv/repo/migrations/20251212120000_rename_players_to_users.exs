defmodule Poker.Repo.Migrations.RenamePlayersToUsers do
  use Ecto.Migration

  def change do
    # Rename the players table to users
    rename table(:players), to: table(:users)

    # Rename the players_tokens table to users_tokens
    rename table(:players_tokens), to: table(:users_tokens)

    # Update the foreign key reference in users_tokens table
    # Drop the old constraint and add the new one
    execute "ALTER TABLE users_tokens DROP CONSTRAINT players_tokens_player_id_fkey",
            "ALTER TABLE users_tokens DROP CONSTRAINT users_tokens_user_id_fkey"

    # Rename the player_id column to user_id in users_tokens
    rename table(:users_tokens), :player_id, to: :user_id

    # Add back the foreign key constraint with the new name
    execute "ALTER TABLE users_tokens ADD CONSTRAINT users_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE",
            "ALTER TABLE users_tokens ADD CONSTRAINT players_tokens_player_id_fkey FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE"

    # Update indexes
    execute "ALTER INDEX players_pkey RENAME TO users_pkey",
            "ALTER INDEX users_pkey RENAME TO players_pkey"

    execute "ALTER INDEX players_email_index RENAME TO users_email_index",
            "ALTER INDEX users_email_index RENAME TO players_email_index"

    execute "ALTER INDEX players_tokens_pkey RENAME TO users_tokens_pkey",
            "ALTER INDEX users_tokens_pkey RENAME TO players_tokens_pkey"

    execute "ALTER INDEX players_tokens_context_token_index RENAME TO users_tokens_context_token_index",
            "ALTER INDEX users_tokens_context_token_index RENAME TO players_tokens_context_token_index"

    execute "ALTER INDEX players_tokens_player_id_index RENAME TO users_tokens_user_id_index",
            "ALTER INDEX users_tokens_user_id_index RENAME TO players_tokens_player_id_index"
  end
end
