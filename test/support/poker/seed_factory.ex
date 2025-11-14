defmodule Poker.SeedFactorySchema do
  use SeedFactory.Schema
  import Commanded.Assertions.EventAssertions
  alias Poker.Tables.Projections.{Hand, Table, Settings, Participant, ParticipantHand}

  def wait_for_events(events) when is_list(events) do
    Enum.each(events, fn event ->
      wait_for_event(Poker.App, event)
    end)
  end

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
      {:ok,
       %{table_id: table_id, settings_id: settings_id, creator_participant_id: participant_id}} =
        Poker.Tables.create_table(args.player, args.settings)

      {:ok, table} = Poker.Repo.find_by_id(Table, table_id)
      {:ok, settings} = Poker.Repo.find_by_id(Settings, settings_id)
      {:ok, participant} = Poker.Repo.find_by_id(Participant, participant_id)

      {:ok,
       %{
         table: table,
         table_settings: settings,
         participants: [participant]
       }}
    end)

    produce(:table)
    produce(:participants)
    produce(:table_settings)
  end

  command :add_participants do
    param(:table, entity: :table)
    param(:players, value: [])
    param(:participants, entity: :participants)

    resolve(fn args ->
      participants =
        Enum.map(args.players, fn player ->
          {:ok, participant_id} = Poker.Tables.join_participant(args.table, player)
          {:ok, participant} = Poker.Repo.find_by_id(Participant, participant_id)

          participant
        end)

      {:ok, %{participants: args.participants ++ participants}}
    end)

    update(:participants)
  end

  command :start_table do
    param(:table, entity: :table, with_traits: [:not_started])
    param(:participants, entity: :participants)

    resolve(fn args ->
      {:ok, hand_id} = Poker.Tables.start_table(args.table)

      wait_for_events([
        Poker.Tables.Events.TableStarted,
        Poker.Tables.Events.HandStarted,
        Poker.Tables.Events.SmallBlindPosted,
        Poker.Tables.Events.BigBlindPosted,
        Poker.Tables.Events.RoundStarted
      ])

      {:ok, table} = Poker.Repo.find_by_id(Table, args.table.id)
      {:ok, hand} = Poker.Repo.find_by_id(Hand, hand_id)

      participant_hands =
        Enum.map(
          args.participants,
          fn participant ->
            {:ok, hand} =
              Poker.Repo.find_by(ParticipantHand,
                table_hand_id: hand.id,
                participant_id: participant.id
              )

            hand
          end
        )

      participants = Enum.map(args.participants, &Poker.Repo.reload!/1)

      {:ok,
       %{
         table: table,
         table_hand: hand,
         participants: participants,
         participant_hands: participant_hands
       }}
    end)

    update(:table)
    produce(:table_hand)
    update(:participants)
    produce(:participant_hands)
  end

  command :sit_out do
    param(:table, entity: :table, with_traits: [:live])
    param(:participants, entity: :participants)
    param(:participant)

    resolve(fn args ->
      :ok = Poker.Tables.sit_out(args.participant)

      wait_for_event(
        Poker.App,
        Poker.Tables.Events.ParticipantSatOut
      )

      participants =
        Enum.map(args.participants, fn participant ->
          if args.participant.id == participant.id,
            do: Poker.Repo.reload(participant),
            else: participant
        end)

      {:ok, %{participants: participants}}
    end)

    update(:participants)
  end

  command :sit_in do
    param(:table, entity: :table, with_traits: [:live])
    param(:participants, entity: :participants)
    param(:participant)

    resolve(fn args ->
      :ok = Poker.Tables.sit_in(args.participant)

      wait_for_event(
        Poker.App,
        Poker.Tables.Events.ParticipantSatIn
      )

      participants =
        Enum.map(args.participants, fn participant ->
          if args.participant.id == participant.id,
            do: Poker.Repo.reload(participant),
            else: participant
        end)

      participant_hands =
        Enum.map(
          args.participants,
          fn participant ->
            {:ok, hand} =
              Poker.Repo.find_by(ParticipantHand,
                table_hand_id: args.table_hand.id,
                participant_id: participant.id
              )

            hand
          end
        )

      {:ok, %{participants: participants}}
    end)

    update(:participants)
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
    param(:table_hand, entity: :table_hand)
    param(:participants, entity: :participants)
    param(:amount)

    resolve(fn args ->
      dbg(args.table_hand.participant_to_act_id)

      participant_to_act =
        Enum.find(args.participants, &(&1.id == args.table_hand.participant_to_act_id))

      :ok = Poker.Tables.raise_hand(participant_to_act, args.amount)

      wait_for_event(
        Poker.App,
        Poker.Tables.Events.ParticipantActedInHand
      )

      participants =
        Enum.map(args.participants, fn participant ->
          if participant.id == participant_to_act.id,
            do: Poker.Repo.reload(participant),
            else: participant
        end)

      table_hand = Poker.Repo.reload!(args.table_hand)

      {:ok, %{participants: participants, table_hand: table_hand}}
    end)

    update(:participants)
    update(:table_hand)
  end

  command :call_hand do
    param(:table, entity: :table, with_traits: [:live])
    param(:table_hand, entity: :table_hand)
    param(:participants, entity: :participants)

    resolve(fn args ->
      participant_to_act =
        Enum.find(args.participants, &(&1.id == args.table_hand.participant_to_act_id))

      dbg(participant_to_act.id)

      :ok = Poker.Tables.call_hand(participant_to_act)

      wait_for_event(
        Poker.App,
        Poker.Tables.Events.ParticipantActedInHand
      )

      participants =
        Enum.map(args.participants, fn participant ->
          if participant.id == participant_to_act.id,
            do: Poker.Repo.reload(participant),
            else: participant
        end)

      table_hand = Poker.Repo.reload!(args.table_hand)

      {:ok, %{participants: participants, table_hand: table_hand}}
    end)

    update(:participants)
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
