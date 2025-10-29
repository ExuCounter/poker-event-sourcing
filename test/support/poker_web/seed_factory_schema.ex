defmodule PokerWeb.SeedFactorySchema do
  use SeedFactory.Schema
  include_schema(Poker.SeedFactorySchema)

  command :create_user_sesion do
    param(:user, entity: :user)
    param(:conn, entity: :conn, with_traits: [:unauthenticated])

    resolve(fn args ->
      {:ok, %{conn: PokerWeb.ConnCase.log_in_user(args.conn, args.user)}}
    end)

    update(:conn)
  end

  command :build_conn do
    resolve(fn _ ->
      conn =
        Phoenix.ConnTest.build_conn()
        |> Plug.Conn.put_private(:phoenix_endpoint, PokerWeb.Endpoint)

      {:ok, %{conn: conn}}
    end)

    produce(:conn)
  end

  trait :unauthenticated, :conn do
    exec(:build_conn)
  end

  trait :user_session, :conn do
    from(:unauthenticated)
    exec(:create_user_sesion)
  end
end
