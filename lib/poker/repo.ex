defmodule Poker.Repo do
  use Boundary

  use Ecto.Repo,
    otp_app: :poker,
    adapter: Ecto.Adapters.Postgres
end
