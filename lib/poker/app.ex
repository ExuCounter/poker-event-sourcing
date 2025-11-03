defmodule Poker.App do
  use Commanded.Application, otp_app: :poker

  router(Poker.Router)
end
