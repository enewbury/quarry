defmodule Quarry.Join do
  @moduledoc false
  require Ecto.Query
  alias Quarry.QueryStruct

  def with_join(query, parent_binding, assoc) do
    binding = String.to_atom("#{parent_binding}_#{assoc}")

    if Ecto.Query.has_named_binding?(query, binding) do
      {query, binding}
    else
      query =
        query
        |> Ecto.Query.join(:left, [{^parent_binding, p}], child in assoc(p, ^assoc))
        |> QueryStruct.with_join_as(binding, assoc)

      {query, binding}
    end
  end

  def join_dependencies(query, root_binding, join_deps) do
    List.foldr(join_deps, {query, root_binding}, fn assoc, {q, binding} ->
      with_join(q, binding, assoc)
    end)
  end
end
