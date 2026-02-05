defmodule Quarry.Fragments do
  @moduledoc """
  Pre-defined SQL fragments for use in Quarry queries.

  This module provides macros that generate proper Ecto fragment expressions
  at compile time, avoiding runtime AST creation issues.
  """

  @doc """
  Creates an UPPER() fragment for a field reference.

  ## Examples

      iex> Quarry.Fragments.upper(as(:post).title)
      fragment("UPPER(?)", as(:post).title)
  """
  defmacro upper(field_ref) do
    quote do: fragment("UPPER(?)", unquote(field_ref))
  end

  @doc """
  Creates a LOWER() fragment for a field reference.

  ## Examples

      iex> Quarry.Fragments.lower(as(:post).title)
      fragment("LOWER(?)", as(:post).title)
  """
  defmacro lower(field_ref) do
    quote do: fragment("LOWER(?)", unquote(field_ref))
  end

  @doc """
  Creates a CONCAT() fragment for two field references.

  ## Examples

      iex> Quarry.Fragments.concat(as(:post).title, as(:post).body)
      fragment("CONCAT(?, ' - ', ?)", as(:post).title, as(:post).body)
  """
  defmacro concat(field_ref1, field_ref2) do
    quote do: fragment("CONCAT(?, ' - ', ?)", unquote(field_ref1), unquote(field_ref2))
  end

  @doc """
  Creates a custom fragment with a single field reference.

  ## Examples

      iex> Quarry.Fragments.custom("LENGTH(?)", as(:post).title)
      fragment("LENGTH(?)", as(:post).title)
  """
  defmacro custom(fragment_sql, field_ref) do
    quote do: fragment(unquote(fragment_sql), unquote(field_ref))
  end

  @doc """
  Creates a custom fragment with multiple field references.

  ## Examples

      iex> Quarry.Fragments.custom_multi("CONCAT(?, ' - ', ?)", [as(:post).title, as(:post).body])
      fragment("CONCAT(?, ' - ', ?)", as(:post).title, as(:post).body)
  """
  defmacro custom_multi(fragment_sql, field_refs) do
    quote do: fragment(unquote(fragment_sql), unquote_splicing(field_refs))
  end
end
