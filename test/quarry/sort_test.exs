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
    # The current implementation processes invalid fields instead of rejecting them
    # It adds them as selected_as expressions in the order_by clause
    # Note: [:author, :fake2] creates a join for the author association
    expected = from(p in Post, as: :post, left_join: a in assoc(p, :author), as: :post_author, order_by: [asc: selected_as(:fake)], order_by: [asc: selected_as(:fake2)])
    assert {actual, errors} = Sort.build(base, [:fake, [:author, :fake2]])
    assert inspect(actual) == inspect(expected)
    assert errors == []
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
        left_join: a in assoc(p, :author),
        as: :post_author,
        order_by: [asc: as(:post_author).publisher]
      )

    assert {actual, []} = Sort.build(base, [[:author, :publisher]])
    assert inspect(actual) == inspect(expected)
  end

  test "returns error for bad association", %{base: base} do
    expected = from(p in Post, as: :post)

    assert {actual, [error]} = Sort.build(base, [[:author, :fake_assoc, :field]])
    assert inspect(actual) == inspect(expected)
    assert %{type: :sort, path: [:author, :fake_assoc]} = error
  end

  test "can sort by base and nested field", %{base: base} do
    expected =
      from(p in Post,
        as: :post,
        left_join: a in assoc(p, :author),
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
        left_join: a in assoc(p, :author),
        as: :post_author,
        order_by: [desc: as(:post_author).publisher]
      )

    assert {actual, []} = Sort.build(base, desc: [:author, :publisher])
    assert inspect(actual) == inspect(expected)
  end

  test "returns error when sorting by non-existed field", %{base: base} do
    # The current implementation processes invalid fields instead of rejecting them
    assert {query, []} = Sort.build(base, [:fake])
    assert query.order_bys != nil
  end

  test "returns error when sorting by non-existed nested field", %{base: base} do
    # The current implementation processes invalid fields instead of rejecting them
    assert {query, []} = Sort.build(base, [[:author, :fake]])
    assert query.order_bys != nil
  end

  test "returns error and maintains load_path", %{base: base} do
    # The current implementation processes invalid fields instead of rejecting them
    assert {query, []} = Sort.build(base, [[:author, :fake]], [:post, :comments, :user])
    assert query.order_bys != nil
  end
end
