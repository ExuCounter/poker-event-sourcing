defmodule Poker.JoinCodesTest do
  use Poker.DataCase

  alias Poker.JoinCodes

  test "next_code/0 returns an 8-character code over the configured alphabet" do
    code = JoinCodes.next_code()

    assert String.length(code) == 8
    assert Regex.match?(~r/^[23456789ABCDEFGHJKLMNPQRSTUVWXYZ]+$/, code)
  end
end
