defmodule Quarry.Sort do
  require Ecto.Query

  alias Quarry.{Join, From}

  @sort_direction [:asc, :desc]

  def build(query, keys) do
    root_binding = From.get_root_binding(query)
    schema = From.get_root_schema(query)
    sort(query, root_binding, schema, [], keys)
  end

  defp sort(query, binding, schema, join_deps, keys) when is_list(keys) do
    Enum.reduce(
      keys,
      query,
      &sort_key(&1, join_deps, query: &2, schema: schema, binding: binding)
    )
  end

  defp sort(query, binding, schema, join_deps, key),
    do: sort(query, binding, schema, join_deps, [key])

  defp sort_key({dir, path}, join_deps, state), do: sort_key(path, dir, join_deps, state)
  defp sort_key(path, join_deps, state), do: sort_key(path, :asc, join_deps, state)

  defp sort_key([field_name], dir, join_deps, state),
    do: sort_key(field_name, dir, join_deps, state)

  defp sort_key([assoc | path], dir, join_deps, state) do
    schema = state[:schema]
    associations = schema.__schema__(:associations)

    if assoc in associations do
      child_schema = schema.__schema__(:association, assoc).related
      state = Keyword.put(state, :schema, child_schema)
      sort_key(path, dir, [assoc | join_deps], state)
    else
      state[:query]
    end
  end

  defp sort_key(field_name, dir, join_deps, state) when is_atom(field_name) do
    if field_name in state[:schema].__schema__(:fields) and dir in @sort_direction do
      {query, join_binding} = Join.join_dependencies(state[:query], state[:binding], join_deps)
      Ecto.Query.order_by(query, [{^dir, field(as(^join_binding), ^field_name)}])
    else
      state[:query]
    end
  end
end
