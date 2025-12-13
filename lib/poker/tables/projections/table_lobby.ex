defmodule Poker.Tables.Projections.TableLobby do
  use Poker, :schema

  defmodule Participant do
    use Ecto.Schema

    @primary_key false
    embedded_schema do
      field :player_id, :binary_id
      field :email, :string
    end
  end

  schema "table_lobby" do
    field :small_blind, :integer
    field :big_blind, :integer
    field :starting_stack, :integer
    field :table_type, Ecto.Enum, values: [:six_max]
    field :seated_count, :integer
    field :seats_count, :integer
    field :status, Ecto.Enum, values: [:waiting, :live, :finished]

    embeds_many :participants, Participant, on_replace: :delete

    timestamps()
  end
end
