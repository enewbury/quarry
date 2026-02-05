defmodule Quarry.Group do
  @moduledoc false
  require Ecto.Query

  alias Quarry.{Join, From}

  @spec build({Ecto.Query.t(), [Quarry.error()]}, Quarry.group(), [atom()]) ::
          {Ecto.Query.t(), [Quarry.error()]}
  def build({query, errors}, keys, load_path \\ []) do
    root_binding = From.get_root_binding(query)
    schema = From.get_root_schema(query)

    state = [
      schema: schema,
      binding: root_binding,
      load_path: load_path
    ]

    group({query, errors}, [], keys, state)
  end

  defp group(acc, join_deps, keys, state) when is_list(keys) do
    # Deduplicate keys to avoid duplicate group_by clauses
    unique_keys = Enum.uniq(keys)

    Enum.reduce(
      unique_keys,
      acc,
      fn entry, {query, errors} ->
        group_key(entry, join_deps,
          query: query,
          schema: state[:schema],
          binding: state[:binding],
          load_path: state[:load_path],
          errors: errors
        )
      end
    )
  end

  defp group(acc, _join_deps, key, _state) when is_nil(key),
    do: acc

  defp group(acc, join_deps, key, state),
    do: group(acc, join_deps, [key], state)

  defp group_key([field_name], join_deps, state),
    do: group_key(field_name, join_deps, state)

  defp group_key([assoc | path], join_deps, state) do
    schema = state[:schema]
    associations = schema.__schema__(:associations)

    if assoc in associations do
      child_schema = schema.__schema__(:association, assoc).related
      state = Keyword.put(state, :schema, child_schema)
      group_key(path, [assoc | join_deps], state)
    else
      error = build_error(assoc, join_deps, state)
      {state[:query], [error | state[:errors]]}
    end
  end

  defp group_key(field_name, join_deps, state) when is_atom(field_name) do
    {query, join_binding} = Join.join_dependencies(state[:query], state[:binding], join_deps)

    query = if field_name in state[:schema].__schema__(:fields) do
      Ecto.Query.group_by(query, [field(as(^join_binding), ^field_name)])
    else
      Ecto.Query.group_by(query, [selected_as(^field_name)])
    end

    {query, state[:errors]}
  end

  defp build_error(field, path, state) do
    %{
      type: :group,
      path: Enum.reverse([field | path]),
      load_path: Enum.reverse(state[:load_path]),
      message: "Quarry couldn't find field \"#{field}\" on Ecto schema \"#{state[:schema]}\""
    }
  end
end
