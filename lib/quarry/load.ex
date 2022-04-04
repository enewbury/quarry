defmodule Quarry.Load do
  @moduledoc false
  require Ecto.Query

  alias Quarry.{Join, From, QueryStruct}

  @spec build({Ecto.Query.t(), [Quarry.error()]}, Quarry.load()) ::
          {Ecto.Query.t(), [Quarry.error()]}
  def build({query, errors}, load_params) do
    root_binding = From.get_root_binding(query)
    schema = From.get_root_schema(query)

    state = [binding: root_binding, schema: schema, path: []]

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
      path =
        state[:path]
        |> List.insert_at(0, assoc)
        |> Enum.reverse()

      error = %{
        type: :load,
        path: path,
        message:
          "Quarry couldn't find filtering field \"#{Enum.join(path, ".")}\" on Ecto schema \"#{state[:schema]}\""
      }

      {query, [error | errors]}
    end
  end

  defp preload_tree({query, errors}, %{cardinality: :one} = association, children, state) do
    %{queryable: child_schema, field: assoc} = association
    binding = Keyword.get(state, :binding)
    path = [assoc | state[:path]]

    {query, join_binding} = Join.with_join(query, binding, assoc)

    query
    |> QueryStruct.add_assoc(Enum.reverse(path), join_binding)
    |> then(&{&1, errors})
    |> load(children, binding: join_binding, schema: child_schema, path: path)
  end

  defp preload_tree({query, errors}, %{cardinality: :many} = association, children, state) do
    %{queryable: child_schema, field: assoc} = association
    binding = Keyword.get(state, :binding)

    ordered_path =
      state[:path]
      |> List.insert_at(0, assoc)
      |> Enum.reverse()

    children = List.wrap(children)

    {subquery, sub_errors} =
      Quarry.build(child_schema,
        filter: Keyword.get(children, :filter, %{}),
        load: Keyword.get(children, :load, children),
        sort: Keyword.get(children, :sort, []),
        limit: Keyword.get(children, :limit),
        offset: Keyword.get(children, :offset),
        binding_prefix: binding
      )

    {QueryStruct.add_preload(query, ordered_path, subquery), sub_errors ++ errors}
  end
end
