defmodule Quarry.Load do
  @moduledoc false
  require Ecto.Query

  alias Quarry.{Join, From, QueryStruct}

  @quarry_opts [:filter, :load, :sort, :limit, :offset]

  @spec build({Ecto.Query.t(), [Quarry.error()]}, Quarry.load()[atom()]) ::
          {Ecto.Query.t(), [Quarry.error()]}
  def build({query, errors}, load_params, load_path \\ []) do
    root_binding = From.get_root_binding(query)
    schema = From.get_root_schema(query)

    state = [binding: root_binding, schema: schema, local_path: [], path: load_path]

    load({query, errors}, load_params, state)
  end

  defp load(acc, load_params, state) do
    load_params
    |> List.wrap()
    |> Enum.reduce(acc, &maybe_preload_tree(&2, &1, state))
  end

  defp maybe_preload_tree(acc, assoc, state) when is_atom(assoc) do
    maybe_preload_tree(acc, {assoc, []}, state)
  end

  defp maybe_preload_tree({query, errors}, {assoc, children}, state) do
    association = state[:schema].__schema__(:association, assoc)

    if association do
      preload_tree({query, errors}, association, children, state)
    else
      {query, [build_error(assoc, state) | errors]}
    end
  end

  defp build_error(field_name, state) do
    %{
      type: :load,
      path: Enum.reverse([field_name | state[:local_path] ++ state[:path]]),
      message: "Quarry couldn't find field \"#{field_name}\" on Ecto schema \"#{state[:schema]}\""
    }
  end

  defp preload_tree({query, errors}, %{cardinality: :one, through: through} = association, children, state) do
    %{field: assoc} = association
    binding = Keyword.get(state, :binding)

    # Get the target schema by traversing the through associations
    target_schema = get_target_schema(state[:schema], through)

    quarry_opts =
      Keyword.merge(extract_nested_opts(children),
        binding_prefix: binding,
        load_path: [assoc | state[:local_path] ++ state[:path]]
      )

    {subquery, sub_errors} = Quarry.build(target_schema, quarry_opts)

    ordered_local_path = Enum.reverse([assoc | state[:local_path]])

    {QueryStruct.add_preload(query, ordered_local_path, subquery), sub_errors ++ errors}
  end

  defp preload_tree({query, errors}, %{cardinality: :one} = association, children, state) do
    %{queryable: child_schema, field: assoc} = association
    binding = Keyword.get(state, :binding)
    local_path = [assoc | state[:local_path]]

    {query, join_binding} = Join.with_join(query, binding, assoc)

    query
    |> QueryStruct.add_assoc(Enum.reverse(local_path), join_binding)
    |> then(&{&1, errors})
    |> load(children,
      binding: join_binding,
      schema: child_schema,
      local_path: local_path,
      path: state[:path]
    )
  end

  defp preload_tree({query, errors}, %{cardinality: :many, through: through} = association, children, state) do
    %{field: assoc} = association
    binding = Keyword.get(state, :binding)

    # Get the target schema by traversing the through associations
    target_schema = get_target_schema(state[:schema], through)

    quarry_opts =
      Keyword.merge(extract_nested_opts(children),
        binding_prefix: binding,
        load_path: [assoc | state[:local_path] ++ state[:path]]
      )

    {subquery, sub_errors} = Quarry.build(target_schema, quarry_opts)

    ordered_local_path = Enum.reverse([assoc | state[:local_path]])

    {QueryStruct.add_preload(query, ordered_local_path, subquery), sub_errors ++ errors}
  end

  defp preload_tree({query, errors}, %{cardinality: :many} = association, children, state) do
    %{queryable: child_schema, field: assoc} = association
    binding = Keyword.get(state, :binding)

    quarry_opts =
      Keyword.merge(extract_nested_opts(children),
        binding_prefix: binding,
        load_path: [assoc | state[:local_path] ++ state[:path]]
      )

    {subquery, sub_errors} = Quarry.build(child_schema, quarry_opts)

    ordered_local_path = Enum.reverse([assoc | state[:local_path]])

    {QueryStruct.add_preload(query, ordered_local_path, subquery), sub_errors ++ errors}
  end

  defp get_target_schema(schema, [last_assoc]) do
    assoc = schema.__schema__(:association, last_assoc)
    assoc.queryable
  end

  defp get_target_schema(schema, [next_assoc | rest]) do
    assoc = schema.__schema__(:association, next_assoc)
    get_target_schema(assoc.queryable, rest)
  end

  defp extract_nested_opts(children) do
    children
    |> List.wrap()
    |> Enum.filter(&is_tuple(&1))
    |> Keyword.take(@quarry_opts)
    |> case do
      [] -> [load: children]
      opts -> opts
    end
  end
end
