defmodule Poker.SeedFactorySchema do
  use SeedFactory.Schema
  import Commanded.Assertions.EventAssertions

  command :create_player do
    param(:email, generate: &Faker.Internet.email/0)

    resolve(fn args ->
      {:ok, player} = Poker.Accounts.register_player(%{email: args.email})
      {:ok, %{player: player}}
    end)

    produce(:player)
  end

  command :create_table do
    param(:player, entity: :player)

    param(:settings,
      value: %{
        small_blind: 10,
        big_blind: 20,
        starting_stack: 1000,
        timeout_seconds: 90
      }
    )

    resolve(fn args ->
      {:ok, table} = Poker.Tables.create_table(args.player, args.settings)

      :ok = Phoenix.PubSub.subscribe(Poker.PubSub, "table:#{table.id}")

      {:ok, %{table: table}}
    end)

    produce(:table)
  end

  command :join_participant do
    param(:player, entity: :player)
    param(:table, entity: :table)

    resolve(fn args ->
      {:ok, participant} = Poker.Tables.join_participant(args.table, args.player)
      {:ok, %{participant: participant}}
    end)

    produce(:participant)
  end

  command :start_table do
    param(:player, entity: :player)
    param(:table, entity: :table, with_traits: [:not_started])

    resolve(fn args ->
      {:ok, table} = Poker.Tables.start_table(args.table)

      wait_for_event(
        Poker.App,
        Poker.Tables.Events.HandStarted
      )

      table = table |> Poker.Repo.preload([:participants, hands: [:participant_hands]])

      {:ok, %{table: table, table_hand: hd(table.hands), participant: hd(table.participants)}}
    end)

    update(:table)
    produce(:table_hand)
    produce(:participant)
  end

  command :sit_out do
    param(:table, entity: :table, with_traits: [:live])
    param(:participant, entity: :participant)

    resolve(fn args ->
      :ok = Poker.Tables.sit_out(args.participant)

      wait_for_event(
        Poker.App,
        Poker.Tables.Events.ParticipantSatOut
      )

      participant = args.participant |> Poker.Repo.reload!()

      {:ok, %{participant: participant}}
    end)

    update(:participant)
  end

  command :sit_in do
    param(:table, entity: :table, with_traits: [:live])
    param(:participant, entity: :participant)

    resolve(fn args ->
      :ok = Poker.Tables.sit_in(args.participant)

      wait_for_event(
        Poker.App,
        Poker.Tables.Events.ParticipantSatIn
      )

      participant = args.participant |> Poker.Repo.reload!()

      {:ok, %{participant: args.participant}}
    end)

    update(:participant)
  end

  # command :fold_hand do
  #   param(:table, entity: :table, with_traits: [:live])
  #   param(:table_hand, entity: :table_hand)
  #   param(:participant, entity: :participant)

  #   resolve(fn args ->
  #     :ok = Poker.Tables.fold_hand(args.participant)

  #     wait_for_event(
  #       Poker.App,
  #       Poker.Tables.Events.ParticipantActedInHand
  #     )
  #   end)

  #   update(:table_hand)
  # end

  # command :check_hand do
  #   param(:table, entity: :table, with_traits: [:live])
  #   param(:table_hand, entity: :table_hand)
  #   param(:participant, entity: :participant)

  #   resolve(fn args ->
  #     :ok = Poker.Tables.check_hand(args.participant)

  #     {:ok, %{table: args.table}}
  #   end)
  # end

  # command :call_hand do
  #   param(:table, entity: :table, with_traits: [:live])
  #   param(:table_hand, entity: :table_hand)
  #   param(:participant, entity: :participant)

  #   resolve(fn args ->
  #     :ok = Poker.Tables.call_hand(args.participant)
  #     {:ok, %{}}
  #   end)
  # end

  command :raise_hand do
    param(:table, entity: :table, with_traits: [:live])
    param(:participant, entity: :participant)
    param(:amount)

    resolve(fn args ->
      :ok = Poker.Tables.raise_hand(args.participant, args.amount)

      wait_for_event(
        Poker.App,
        Poker.Tables.Events.ParticipantActedInHand
      )

      table = args.table |> Poker.Repo.preload(hands: [:participant_hands])

      {:ok, %{table_hand: List.last(table.hands)}}
    end)

    update(:table_hand)
  end

  # command :all_in_hand do
  #   param(:participant, entity: :participant)

  #   resolve(fn args ->
  #     :ok = Poker.Tables.all_in_hand(args.participant)
  #     {:ok, %{}}
  #   end)
  # end

  # command :sit_out_participant do
  #   param(:participant, entity: :participant)

  #   resolve(fn args ->
  #     :ok = Poker.Tables.sit_out_participant(args.participant)
  #     {:ok, %{}}
  #   end)
  # end

  trait :not_started, :table do
    exec(:create_table)
  end

  trait :live, :table do
    from(:not_started)
    exec(:start_table)
  end
end
