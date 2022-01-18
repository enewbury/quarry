defmodule Quarry.QueryStruct do
  @moduledoc false

  def add_assoc(query, path, join_binding) do
    binding_index = query.aliases[join_binding]
    Map.update!(query, :assocs, &put_in(&1, path, {binding_index, []}))
  end

  def add_preload(query, path, subquery) do
    Map.update!(query, :preloads, &put_in(&1, path, subquery))
  end

  def with_alias(query, binding) do
    Map.update!(query, :aliases, &Map.put(&1, binding, Enum.count(&1)))
  end

  def with_from_as(query, binding) do
    Map.update!(query, :from, &Map.put(&1, :as, binding))
  end

  def with_join_as(query, binding, assoc) do
    Map.update!(query, :joins, fn joins ->
      update_in(
        joins,
        [Access.filter(&match?(%{assoc: {_, ^assoc}}, &1))],
        &Map.put(&1, :as, binding)
      )
    end)
  end
end
