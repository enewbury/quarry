defmodule Quarry.Join do
  @moduledoc false
  require Ecto.Query

  def with_join(query, parent_binding, assoc) do
    binding = String.to_atom("#{parent_binding}_#{assoc}")

    if Ecto.Query.has_named_binding?(query, binding) do
      {query, binding}
    else
      query =
        query
        |> Ecto.Query.join(:inner, [{^parent_binding, p}], child in assoc(p, ^assoc))
        |> with_alias(binding)
        |> with_join_as(binding, assoc)

      {query, binding}
    end
  end

  def join_dependencies(query, root_binding, join_deps) do
    List.foldr(join_deps, {query, root_binding}, fn assoc, {q, binding} ->
      with_join(q, binding, assoc)
    end)
  end

  defp with_alias(query, binding) do
    Map.update!(query, :aliases, &Map.put(&1, binding, Enum.count(&1)))
  end

  defp with_join_as(query, binding, assoc) do
    Map.update!(query, :joins, fn joins ->
      update_in(
        joins,
        [Access.filter(&match?(%{assoc: {_, ^assoc}}, &1))],
        &Map.put(&1, :as, binding)
      )
    end)
  end
end
