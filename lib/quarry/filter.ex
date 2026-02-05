defmodule Quarry.Filter do
  @moduledoc false
  require Ecto.Query

  alias Quarry.{Join, From}

  @type filter :: %{optional(atom()) => String.t() | number() | filter()}
  @spec build({Ecto.Query.t(), [Quarry.error()]}, Quarry.filter(), [atom()]) ::
          {Ecto.Query.t(), [Quarry.error()]}
  def build({query, errors}, filters, load_path \\ []) do
    root_binding = From.get_root_binding(query)
    schema = From.get_root_schema(query)

    filter({query, errors}, filters,
      binding: root_binding,
      schema: schema,
      path: [],
      load_path: load_path
    )
  end

  defp filter(acc, filters, state) do
    Enum.reduce(filters, acc, &maybe_filter_field(&1, &2, state))
  end

  defp maybe_filter_field({field_name, value} = entry, {query, errors}, state) do
    fields = state[:schema].__schema__(:fields)
    association = state[:schema].__schema__(:associations)

    if (is_map(value) && field_name in association) || field_name in fields do
      filter_field(entry, {query, errors}, state)
    else
      {query, [build_error(field_name, state) | errors]}
    end
  end

  defp build_error(field_name, state) do
    %{
      type: :filter,
      path: Enum.reverse([field_name | state[:path]]),
      load_path: Enum.reverse(state[:load_path]),
      message: "Quarry couldn't find field \"#{field_name}\" on Ecto schema \"#{state[:schema]}\""
    }
  end

  defp filter_field({field_name, child_filter}, acc, state) when is_map(child_filter) do
    child_schema = state[:schema].__schema__(:association, field_name).related

    state =
      state
      |> Keyword.put(:schema, child_schema)
      |> Keyword.update!(:path, &List.insert_at(&1, 0, field_name))

    filter(acc, child_filter, state)
  end

  defp filter_field({field_name, values}, {query, errors}, state) when is_list(values) do
    {query, join_binding} = Join.join_dependencies(query, state[:binding], state[:path])
    query = Ecto.Query.where(query, field(as(^join_binding), ^field_name) in ^values)
    {query, errors}
  end

  defp filter_field({field_name, value}, acc, state) when not is_tuple(value) do
    filter_field({field_name, {:eq, value}}, acc, state)
  end

  defp filter_field({field_name, {operation, value}}, {query, errors}, state) do
    query
    |> Join.join_dependencies(state[:binding], state[:path])
    |> filter_by_operation(field_name, operation, value)
    |> then(&{&1, errors})
  end

  defp filter_by_operation({query, join_binding}, field_name, :eq, nil) do
    Ecto.Query.where(query, is_nil(field(as(^join_binding), ^field_name)))
  end

  defp filter_by_operation({query, join_binding}, field_name, :eq, value) do
    Ecto.Query.where(query, field(as(^join_binding), ^field_name) == ^value)
  end

  defp filter_by_operation({query, join_binding}, field_name, :neq, nil) do
    Ecto.Query.where(query, not is_nil(field(as(^join_binding), ^field_name)))
  end

  defp filter_by_operation({query, join_binding}, field_name, :neq, value) do
    Ecto.Query.where(query, field(as(^join_binding), ^field_name) != ^value)
  end

  defp filter_by_operation({query, join_binding}, field_name, :lt, value) do
    Ecto.Query.where(query, field(as(^join_binding), ^field_name) < ^value)
  end

  defp filter_by_operation({query, join_binding}, field_name, :gt, value) do
    Ecto.Query.where(query, field(as(^join_binding), ^field_name) > ^value)
  end

  defp filter_by_operation({query, join_binding}, field_name, :lte, value) do
    Ecto.Query.where(query, field(as(^join_binding), ^field_name) <= ^value)
  end

  defp filter_by_operation({query, join_binding}, field_name, :gte, value) do
    Ecto.Query.where(query, field(as(^join_binding), ^field_name) >= ^value)
  end

  defp filter_by_operation({query, join_binding}, field_name, :starts_with, value) do
    Ecto.Query.where(query, ilike(field(as(^join_binding), ^field_name), ^"#{value}%"))
  end

  defp filter_by_operation({query, join_binding}, field_name, :ends_with, value) do
    Ecto.Query.where(query, ilike(field(as(^join_binding), ^field_name), ^"%#{value}"))
  end

  defp filter_by_operation({query, join_binding}, field_name, :contains, value) do
    Ecto.Query.where(query, ilike(field(as(^join_binding), ^field_name), ^"%#{value}%"))
  end
end
