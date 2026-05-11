defmodule Poker.Repo.Migrations.CreateJoinCodesSeq do
  use Ecto.Migration

  # Postgres sequences are atomic and monotonic across concurrent inserts.
  # `nextval/1` is the only allocation point; gaps are acceptable.
  # Starting at 10_000_000 keeps codes 8+ digits even if the encoding
  # is ever swapped for plain zero-padded numbers.
  def up do
    execute("CREATE SEQUENCE join_codes_seq START WITH 10000000 INCREMENT BY 1")
  end

  def down do
    execute("DROP SEQUENCE join_codes_seq")
  end
end
