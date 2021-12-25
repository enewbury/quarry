defmodule Quarry.Load do
  require Ecto.Query

  alias Quarry.{Join, From, Utils}

  def build(query, load) do
    root_binding = From.get_root_binding(query)
    schema = From.get_root_schema(query)
    load(query, load, binding: root_binding, schema: schema)
  end

  defp load(query, load, state) do
    load
    |> List.wrap()
    |> Enum.reduce(query, &preload_tree(&2, &1, state))
  end

  defp preload_tree(query, assoc, state) when is_atom(assoc) do
    preload_tree(query, {assoc, []}, state)
  end

  defp preload_tree(query, {assoc, children}, state) do
    case Keyword.get(state, :schema).__schema__(:association, assoc) do
      nil -> query
      association -> add_preload_tree(query, association, children, state)
    end
  end

  defp add_preload_tree(query, %{cardinality: :one} = association, children, state) do
    %{queryable: child_schema, field: assoc} = association
    binding = Keyword.get(state, :binding)
    bound_path = [assoc | Keyword.get(state, :bound_path, [])]

    {query, join_binding} = Join.with_join(query, binding, assoc)
    binding_index = query.aliases[join_binding]

    query
    |> Map.update!(:assocs, &put_in(&1, Enum.reverse(bound_path), {binding_index, []}))
    |> load(children,
      binding: join_binding,
      schema: child_schema,
      bound_path: [Access.elem(1) | bound_path],
      unbound_path: [assoc | Keyword.get(state, :unbound_path, [])]
    )
  end

  defp add_preload_tree(query, %{cardinality: :many} = association, children, state) do
    %{queryable: child_schema, field: assoc} = association
    binding = Keyword.get(state, :binding)

    unbound_path =
      [assoc | Keyword.get(state, :unbound_path, [])]
      |> Enum.reverse()
      |> Enum.map(&Utils.access_keyword(&1, []))

    children = List.wrap(children)

    subquery =
      Quarry.build(child_schema,
        filter: Keyword.get(children, :filter, %{}),
        load: Keyword.get(children, :load, children),
        sort: Keyword.get(children, :sort, []),
        limit: Keyword.get(children, :limit),
        offset: Keyword.get(children, :offset),
        binding_prefix: binding
      )

    Map.update!(query, :preloads, &put_in(&1, unbound_path, subquery))
  end
end
