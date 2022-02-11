defmodule Quarry.Filter do
  @moduledoc false
  require Ecto.Query

  alias Quarry.{Join, From}

  @type filter :: %{optional(atom()) => String.t() | number() | filter()}

  @spec build(Ecto.Query.t(), Quarry.filter()) :: Ecto.Query.t()
  def build(query, filters) do
    root_binding = From.get_root_binding(query)
    schema = From.get_root_schema(query)
    filter(query, root_binding, schema, [], filters)
  end

  defp filter(query, binding, schema, join_deps, filters) do
    Enum.reduce(filters, query, &filter_key(&1, &2, binding, schema, join_deps))
  end

  defp filter_key({field_name, %{op: op, value: value}}, query, binding, schema, join_deps) do
    filter_key({field_name, {op, value}}, query, binding, schema, join_deps)
  end

  defp filter_key({field_name, child_filter}, query, binding, schema, join_deps)
       when is_map(child_filter) do
    assocations = schema.__schema__(:associations)

    if field_name in assocations do
      child_schema = schema.__schema__(:association, field_name).related
      filter(query, binding, child_schema, [field_name | join_deps], child_filter)
    else
      query
    end
  end

  defp filter_key({field_name, values}, query, binding, schema, join_deps)
       when is_list(values) do
    if field_name in schema.__schema__(:fields) do
      {query, join_binding} = Join.join_dependencies(query, binding, join_deps)
      Ecto.Query.where(query, field(as(^join_binding), ^field_name) in ^values)
    else
      query
    end
  end

  defp filter_key({field_name, value}, query, binding, schema, join_deps)
       when not is_tuple(value) do
    filter_key({field_name, {:eq, value}}, query, binding, schema, join_deps)
  end

  defp filter_key({field_name, {operation, value}}, query, binding, schema, join_deps) do
    if field_name in schema.__schema__(:fields) do
      {query, join_binding} = Join.join_dependencies(query, binding, join_deps)
      filter_by_operation(query, join_binding, field_name, operation, value)
    else
      query
    end
  end

  defp filter_by_operation(query, join_binding, field_name, :eq, value) do
    Ecto.Query.where(query, field(as(^join_binding), ^field_name) == ^value)
  end

  defp filter_by_operation(query, join_binding, field_name, :lt, value) do
    Ecto.Query.where(query, field(as(^join_binding), ^field_name) < ^value)
  end

  defp filter_by_operation(query, join_binding, field_name, :gt, value) do
    Ecto.Query.where(query, field(as(^join_binding), ^field_name) > ^value)
  end

  defp filter_by_operation(query, join_binding, field_name, :lte, value) do
    Ecto.Query.where(query, field(as(^join_binding), ^field_name) <= ^value)
  end

  defp filter_by_operation(query, join_binding, field_name, :gte, value) do
    Ecto.Query.where(query, field(as(^join_binding), ^field_name) >= ^value)
  end

  defp filter_by_operation(query, join_binding, field_name, :starts_with, value) do
    Ecto.Query.where(query, ilike(field(as(^join_binding), ^field_name), ^"#{value}%"))
  end

  defp filter_by_operation(query, join_binding, field_name, :ends_with, value) do
    Ecto.Query.where(query, ilike(field(as(^join_binding), ^field_name), ^"%#{value}"))
  end
end
