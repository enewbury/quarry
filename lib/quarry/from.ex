defmodule Quarry.From do
  require Ecto.Query

  def build(schema, bind_prefix \\ nil) do
    raw_binding = schema |> Module.split() |> List.last() |> String.downcase() |> String.to_atom()

    binding =
      if is_nil(bind_prefix),
        do: raw_binding,
        else: String.to_atom("#{bind_prefix}_#{raw_binding}")

    Ecto.Query.from(p in schema) |> with_alias(binding) |> with_from_as(binding)
  end

  def get_root_binding(query), do: query.from.as
  def get_root_schema(query), do: elem(query.from.source, 1)

  defp with_alias(query, binding) do
    Map.update!(query, :aliases, &Map.put(&1, binding, Enum.count(&1)))
  end

  defp with_from_as(query, binding) do
    Map.update!(query, :from, &Map.put(&1, :as, binding))
  end
end
