defmodule Quarry.QueryStruct do
  @moduledoc false

  def add_assoc(query, path, join_binding) do
    binding_index = query.aliases[join_binding]
    Map.update!(query, :assocs, &put_in(&1, path, {binding_index, []}))
  end

  def add_preload(query, path, subquery) do
    Map.update!(query, :preloads, &put_in(&1, path, subquery))
  end

  def with_from_as(query, binding) do
    query
    |> Map.update!(:aliases, &Map.put(&1, binding, 0))
    |> Map.update!(:from, &Map.put(&1, :as, binding))
  end

  def with_join_as(query, binding, assoc) do
    query
    |> Map.update!(:aliases, &Map.put(&1, binding, Enum.count(query.joins)))
    |> Map.update!(:joins, fn joins ->
      update_in(
        joins,
        [Access.filter(&match?(%{assoc: {_, ^assoc}}, &1))],
        &Map.put(&1, :as, binding)
      )
    end)
  end
end
