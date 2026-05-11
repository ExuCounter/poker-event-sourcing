defmodule Poker.JoinCodes do
  @moduledoc """
  Generates short, opaque join codes for cash games and tournaments.

  A Postgres sequence (`join_codes_seq`) is the single source of truth for
  monotonic, collision-free integer ids. Sqids encodes each integer into an
  8-character string over a 32-character alphabet that excludes visually
  ambiguous glyphs (0/O, 1/I/l).
  """

  @alphabet "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"
  @min_length 8

  @doc """
  Reserves the next id from the sequence and encodes it as an 8-char string.
  """
  def next_code do
    %{rows: [[id]]} = Ecto.Adapters.SQL.query!(Poker.Repo, "SELECT nextval('join_codes_seq')", [])
    {:ok, code} = Sqids.encode(sqids(), [id])
    code
  end

  defp sqids do
    {:ok, sqids} = Sqids.new(alphabet: @alphabet, min_length: @min_length)
    sqids
  end
end
