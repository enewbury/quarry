defmodule Quarry do
  require Ecto.Query

  alias Quarry.{From, Filter, Preload, Sort}

  def build(schema, opts \\ []) do
    schema
    |> From.build(Keyword.get(opts, :binding_prefix))
    |> Filter.build(Keyword.get(opts, :filter, %{}))
    |> Preload.build(Keyword.get(opts, :preloads, []))
    |> Sort.build(Keyword.get(opts, :sort, []))
    |> limit(Keyword.get(opts, :limit))
    |> offset(Keyword.get(opts, :offset))
  end

  defp limit(query, value) when is_integer(value), do: Ecto.Query.limit(query, ^value)
  defp limit(query, _limit), do: query

  def offset(query, value) when is_integer(value), do: Ecto.Query.offset(query, ^value)
  def offset(query, _value), do: query
end
