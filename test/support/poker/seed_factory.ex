defmodule Poker.SeedFactorySchema do
  use SeedFactory.Schema
  import Commanded.Assertions.EventAssertions
  # alias Poker.Tables.Projections.{Hand, Table, Settings, Participant, ParticipantHand}

  def wait_for_events(events) when is_list(events) do
    Enum.each(events, fn event ->
      wait_for_event(Poker.App, event)
    end)
  end

  def aggregate_state(:user, user_id) do
    Commanded.Aggregates.Aggregate.aggregate_state(
      Poker.App,
      Poker.Accounts.Aggregates.User,
      "user-" <> user_id
    )
  end

  def aggregate_state(:table, table_id) do
    Commanded.Aggregates.Aggregate.aggregate_state(
      Poker.App,
      Poker.Tables.Aggregates.Table,
      "table-" <> table_id
    )
  end

  def get_table_positions(table) do
    table.participant_hands
    |> Enum.map(fn hand ->
      {hand.position,
       %{
         hand: hand,
         participant: Enum.find(table.participants, &(&1.id == hand.participant_id))
       }}
    end)
    |> Enum.into(%{})
  end

  command :create_player do
    param(:email, generate: &Faker.Internet.email/0)

    resolve(fn args ->
      {:ok, user} = Poker.Accounts.register_user(%{email: args.email})

      {:ok, %{player: user}}
    end)

    produce(:player)
  end

  command :create_table do
    param(:player, entity: :player)
    param(:type, value: :six_max)

    param(:settings,
      value: %{
        small_blind: 10,
        big_blind: 20,
        starting_stack: 1000,
        timeout_seconds: 90
      }
    )

    resolve(fn args ->
      settings = args.settings |> Map.put(:table_type, args.type)

      {:ok, %{table_id: table_id}} = Poker.Tables.create_table(args.player.id, settings)

      aggregate_state = aggregate_state(:table, table_id)

      {:ok, %{table: aggregate_state}}
    end)

    produce(:table)
  end

  command :add_participants do
    param(:table, entity: :table)
    param(:players, value: [])

    resolve(fn args ->
      participants =
        args.players
        |> Enum.map(fn
          {player, attrs} -> {player, attrs}
          player -> {player, %{}}
        end)
        |> Enum.map(fn {player, attrs} ->
          {:ok, _participant_id} = Poker.Tables.join_participant(args.table, player, attrs)
        end)

      table = aggregate_state(:table, args.table.id)

      {:ok, %{table: table}}
    end)

    update(:table)
  end

  command :start_table do
    param(:table, entity: :table, with_traits: [:not_ready])

    resolve(fn args ->
      {:ok, _hand_id} = Poker.Tables.start_table(args.table)

      table = aggregate_state(:table, args.table.id)
      positions = get_table_positions(table)

      {:ok, %{table: table, positions: positions}}
    end)

    update(:table)
    produce(:positions)
  end

  command :call_hand do
    param(:table, entity: :table, with_traits: [:live])

    resolve(fn args ->
      :ok = Poker.Tables.call_hand(args.table.id, args.table.round.participant_to_act_id)

      table = aggregate_state(:table, args.table.id)
      positions = get_table_positions(table)

      {:ok, %{table: table, positions: positions}}
    end)

    update(:table)
    update(:positions)
  end

  command :fold_hand do
    param(:table, entity: :table, with_traits: [:live])

    resolve(fn args ->
      :ok = Poker.Tables.fold_hand(args.table.id, args.table.round.participant_to_act_id)

      table = aggregate_state(:table, args.table.id)
      positions = get_table_positions(table)

      {:ok, %{table: table, positions: positions}}
    end)

    update(:table)
    update(:positions)
  end

  command :advance_round do
    param(:table, entity: :table, with_traits: [:live])

    resolve(fn args ->
      args.table.participants
      |> Enum.each(fn _participant ->
        %{
          round: %{
            participant_to_act_id: participant_to_act_id
          }
        } = aggregate_state(:table, args.table.id)

        :ok = Poker.Tables.call_hand(args.table.id, participant_to_act_id)
      end)

      table = aggregate_state(:table, args.table.id)

      {:ok, %{table: table}}
    end)

    update(:table)
  end

  command :start_runout do
    param(:table, entity: :table, with_traits: [:live])

    resolve(fn args ->
      args.table.participants
      |> Enum.each(fn _participant ->
        %{
          round: %{
            participant_to_act_id: participant_to_act_id
          }
        } = aggregate_state(:table, args.table.id)

        :ok = Poker.Tables.all_in_hand(args.table.id, participant_to_act_id)
      end)

      wait_for_event(
        Poker.App,
        Poker.Tables.Events.HandFinished
      )

      table = aggregate_state(:table, args.table.id)

      {:ok, %{table: table}}
    end)

    update(:table)
  end

  # command :sit_out do
  #   param(:table_hand, entity: :table_hand)
  #   param(:participants, entity: :participants)
  #   param(:participant)

  #   resolve(fn args ->
  #     :ok = Poker.Tables.sit_out(args.participant)

  #     wait_for_event(
  #       Poker.App,
  #       Poker.Tables.Events.ParticipantSatOut
  #     )

  #     participants =
  #       Enum.map(args.participants, fn participant ->
  #         if args.participant.id == participant.id,
  #           do: Poker.Repo.reload(participant),
  #           else: participant
  #       end)

  #     {:ok, %{participants: participants}}
  #   end)

  #   update(:participants)
  # end

  # command :sit_in do
  #   param(:table, entity: :table, with_traits: [:live])
  #   param(:participants, entity: :participants)
  #   param(:participant)

  #   resolve(fn args ->
  #     :ok = Poker.Tables.sit_in(args.participant)

  #     wait_for_event(
  #       Poker.App,
  #       Poker.Tables.Events.ParticipantSatIn
  #     )

  #     participants =
  #       Enum.map(args.participants, fn participant ->
  #         if args.participant.id == participant.id,
  #           do: Poker.Repo.reload(participant),
  #           else: participant
  #       end)

  #     participant_hands =
  #       Enum.map(
  #         args.participants,
  #         fn participant ->
  #           {:ok, hand} =
  #             Poker.Repo.find_by(ParticipantHand,
  #               table_hand_id: args.table_hand.id,
  #               participant_id: participant.id
  #             )

  #           hand
  #         end
  #       )

  #     {:ok, %{participants: participants}}
  #   end)

  #   update(:participants)
  # end

  # command :raise_hand do
  #   param(:table, entity: :table, with_traits: [:live])
  #   param(:table_hand, entity: :table_hand)
  #   param(:participants, entity: :participants)
  #   param(:amount)

  #   resolve(fn args ->
  #     participant_to_act =
  #       Enum.find(args.participants, &(&1.id == args.table_hand.participant_to_act_id))

  #     :ok = Poker.Tables.raise_hand(participant_to_act, args.amount)

  #     wait_for_event(
  #       Poker.App,
  #       Poker.Tables.Events.ParticipantActedInHand
  #     )

  #     participants =
  #       Enum.map(args.participants, fn participant ->
  #         if participant.id == participant_to_act.id,
  #           do: Poker.Repo.reload(participant),
  #           else: participant
  #       end)

  #     table_hand = Poker.Repo.reload!(args.table_hand)

  #     participant_to_act = Enum.find(participants, &(&1.id == table_hand.participant_to_act_id))

  #     {:ok,
  #      %{
  #        participants: participants,
  #        table_hand: table_hand,
  #        participant_to_act: participant_to_act
  #      }}
  #   end)

  #   update(:participants)
  #   update(:table_hand)
  #   update(:participant_to_act)
  # end

  # command :fold_hand do
  #   param(:table, entity: :table, with_traits: [:live])
  #   param(:table_hand, entity: :table_hand)
  #   param(:participants, entity: :participants)

  #   resolve(fn args ->
  #     participant_to_act =
  #       Enum.find(args.participants, &(&1.id == args.table_hand.participant_to_act_id))

  #     :ok = Poker.Tables.fold_hand(participant_to_act)

  #     wait_for_event(
  #       Poker.App,
  #       Poker.Tables.Events.ParticipantActedInHand
  #     )

  #     participants =
  #       Enum.map(args.participants, fn participant ->
  #         if participant.id == participant_to_act.id,
  #           do: Poker.Repo.reload(participant),
  #           else: participant
  #       end)

  #     table_hand = Poker.Repo.reload!(args.table_hand)

  #     participant_to_act = Enum.find(participants, &(&1.id == table_hand.participant_to_act_id))

  #     {:ok,
  #      %{
  #        participants: participants,
  #        table_hand: table_hand,
  #        participant_to_act: participant_to_act
  #      }}
  #   end)

  #   update(:participants)
  #   update(:table_hand)
  #   update(:participant_to_act)
  # end

  trait :not_ready, :table do
    exec(:create_table)
  end

  trait :live, :table do
    exec(:start_table)
  end
end
