defmodule Quarry.Sort do
  @moduledoc false
  require Ecto.Query

  alias Quarry.{Join, From}

  @sort_direction [:asc, :desc]

  @spec build({Ecto.Query.t(), [Quarry.error()]}, Quarry.sort()) ::
          {Ecto.Query.t(), [Qurry.error()]}
  def build({query, errors}, keys, load_path \\ []) do
    root_binding = From.get_root_binding(query)
    schema = From.get_root_schema(query)

    state = [
      schema: schema,
      binding: root_binding,
      load_path: load_path
    ]

    sort({query, errors}, [], keys, state)
  end

  defp sort(acc, join_deps, keys, state) when is_list(keys) do
    Enum.reduce(
      keys,
      acc,
      fn entry, {query, errors} ->
        sort_key(entry, join_deps,
          query: query,
          schema: state[:schema],
          binding: state[:binding],
          load_path: state[:load_path],
          errors: errors
        )
      end
    )
  end

  defp sort(acc, join_deps, key, state),
    do: sort(acc, join_deps, [key], state)

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
      error = build_error(assoc, join_deps, state)
      {state[:query], [error | state[:errors]]}
    end
  end

  defp sort_key(field_name, dir, join_deps, state) when is_atom(field_name) do
    if field_name in state[:schema].__schema__(:fields) and dir in @sort_direction do
      {query, join_binding} = Join.join_dependencies(state[:query], state[:binding], join_deps)
      query = Ecto.Query.order_by(query, [{^dir, field(as(^join_binding), ^field_name)}])
      {query, state[:errors]}
    else
      error = build_error(field_name, join_deps, state)
      {state[:query], [error | state[:errors]]}
    end
  end

  defp build_error(field, path, state) do
    %{
      type: :sort,
      path: Enum.reverse([field | path]),
      load_path: Enum.reverse(state[:load_path]),
      message: "Quarry couldn't find field \"#{field}\" on Ecto schema \"#{state[:schema]}\""
    }
  end
end
