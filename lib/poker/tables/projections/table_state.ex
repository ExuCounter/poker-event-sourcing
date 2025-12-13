defmodule Poker.Tables.Projections.TableState do
  use Poker, :schema

  defmodule Pot do
    use Ecto.Schema

    @primary_key false
    embedded_schema do
      field :amount, :integer
    end
  end

  defmodule ParticipantHand do
    use Ecto.Schema

    @primary_key false
    embedded_schema do
      field :seat_number, :integer
      field :participant_id, :binary_id
      field :hole_cards, {:array, :string}

      field :position, Ecto.Enum,
        values: [:dealer, :small_blind, :big_blind, :utg, :utg_plus_one, :cutoff]

      field :status, Ecto.Enum, values: [:active, :folded, :all_in]
    end
  end

  schema "table_state" do
    field :hand_id, :binary_id
    field :round_type, Ecto.Enum, values: [:preflop, :flop, :turn, :river]
    field :community_cards, {:array, :string}
    field :participant_to_act_id, :binary_id

    embeds_many :pots, Pot, on_replace: :delete
    embeds_many :participant_hands, ParticipantHand, on_replace: :delete

    timestamps()
  end
end
