defmodule Poker.Repo do
  use Ecto.Repo,
    otp_app: :poker,
    adapter: Ecto.Adapters.Postgres

  def validate_changeset(attrs, changeset) do
    changeset = changeset.(attrs)

    if changeset.valid? do
      {:ok, Ecto.Changeset.apply_changes(changeset)}
    else
      {:error, changeset}
    end
  end

  def exists_with?(query, expr) do
    query
    |> Poker.Queries.filter_with(expr)
    |> exists?()
  end

  def find_by_id(query, id, opts \\ []) do
    find_by(query, [id: id], opts)
  end

  def find_by(query, clauses, opts \\ []) do
    query = Ecto.Queryable.to_query(query)

    case Poker.Repo.get_by(query, clauses) do
      nil ->
        message =
          case {opts[:error_message], query} do
            {message, _query} when is_binary(message) ->
              message

            {nil, module} when is_atom(module) ->
              "#{humanize_struct_name(module)} not found"

            {nil, query} ->
              module = module_from_query(query)
              "#{humanize_struct_name(module)} not found"
          end

        {:error, %{message: message, status: :not_found}}

      record ->
        {:ok, record}
    end
  end

  defp module_from_query(%{from: %{source: {_, module}}}), do: module

  defp module_from_query(%{from: %{source: %{query: subquery} = source}}) when is_map(source) do
    module_from_query(subquery)
  end

  defp humanize_struct_name(module) do
    module
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
    |> Phoenix.Naming.humanize()
  end
end
