defmodule Quarry.SortTest do
  use ExUnit.Case
  doctest Quarry.Sort
  alias Quarry.Sort

  import Ecto.Query
  alias Quarry.{Post, Sort}

  setup do
    %{base: {from(p in Post, as: :post), []}}
  end

  test "can sort by top level field", %{base: base} do
    expected = from(p in Post, as: :post, order_by: [asc: as(:post).title])
    assert {actual, []} = Sort.build(base, :title)
    assert inspect(actual) == inspect(expected)
  end

  test "ignores bad sort field", %{base: base} do
    expected = from(p in Post, as: :post)
    assert {actual, errors} = Sort.build(base, [:fake, [:author, :fake2]])
    assert inspect(actual) == inspect(expected)
    assert [%{path: [:fake]}, %{path: [:author, :fake2]}] = Enum.sort_by(errors, & &1.message)
  end

  test "can sort by multiple fields", %{base: base} do
    expected =
      from(p in Post,
        as: :post,
        order_by: [asc: as(:post).title],
        order_by: [asc: as(:post).body]
      )

    assert {actual, []} = Sort.build(base, [:title, :body])
    assert inspect(actual) == inspect(expected)
  end

  test "can sort by nested field", %{base: base} do
    expected =
      from(p in Post,
        as: :post,
        join: a in assoc(p, :author),
        as: :post_author,
        order_by: [asc: as(:post_author).publisher]
      )

    assert {actual, []} = Sort.build(base, [[:author, :publisher]])
    assert inspect(actual) == inspect(expected)
  end

  test "can sort by base and nested field", %{base: base} do
    expected =
      from(p in Post,
        as: :post,
        join: a in assoc(p, :author),
        as: :post_author,
        order_by: [asc: as(:post).title],
        order_by: [asc: as(:post_author).publisher]
      )

    assert {actual, []} = Sort.build(base, [:title, [:author, :publisher]])
    assert inspect(actual) == inspect(expected)
  end

  test "can sort with desc", %{base: base} do
    expected = from(p in Post, as: :post, order_by: [desc: as(:post).title])
    assert {actual, []} = Sort.build(base, desc: :title)
    assert inspect(actual) == inspect(expected)
  end

  test "can sort desc with nested value", %{base: base} do
    expected =
      from(p in Post,
        as: :post,
        join: a in assoc(p, :author),
        as: :post_author,
        order_by: [desc: as(:post_author).publisher]
      )

    assert {actual, []} = Sort.build(base, desc: [:author, :publisher])
    assert inspect(actual) == inspect(expected)
  end
end
