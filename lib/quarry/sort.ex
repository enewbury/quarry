defmodule Quarry.Sort do
  require Ecto.Query

  alias Quarry.{Join, From}

  def build(query, keys) do
    root_binding = From.get_root_binding(query)
    schema = From.get_root_schema(query)
    sort(query, root_binding, schema, [], keys)
  end

  defp sort(query, binding, schema, join_deps, keys) when is_list(keys) do
    Enum.reduce(keys, query, &sort_key(&1, &2, binding, schema, join_deps))
  end

  defp sort(query, binding, schema, join_deps, key),
    do: sort(query, binding, schema, join_deps, [key])

  defp sort_key({field_name, children}, query, binding, schema, join_deps) do
    assocations = schema.__schema__(:associations)

    if field_name in assocations do
      child_schema = schema.__schema__(:association, field_name).related
      sort(query, binding, child_schema, [field_name | join_deps], children)
    else
      query
    end
  end

  defp sort_key(value, query, binding, schema, join_deps) when is_atom(value) do
    sort_key(%{direction: :asc, value: value}, query, binding, schema, join_deps)
  end

  defp sort_key(%{direction: dir, value: field_name}, query, binding, schema, join_deps) do
    if field_name in schema.__schema__(:fields) and dir in [:asc, :desc] do
      {query, join_binding} = Join.join_dependencies(query, binding, join_deps)
      Ecto.Query.order_by(query, [{^dir, field(as(^join_binding), ^field_name)}])
    else
      query
    end
  end
end
