defmodule Quarry.GroupTest do
  use ExUnit.Case
  doctest Quarry.Group
  alias Quarry.Group

  import Ecto.Query
  alias Quarry.{Post, Group}

  setup do
    %{base: {from(p in Post, as: :post), []}}
  end

  test "can group by top level field", %{base: base} do
    expected = from(p in Post, as: :post, group_by: [as(:post).title])
    assert {actual, []} = Group.build(base, :title)
    assert inspect(actual) == inspect(expected)
  end

  test "can group by multiple fields", %{base: base} do
    expected =
      from(p in Post,
        as: :post,
        group_by: [as(:post).title],
        group_by: [as(:post).body]
      )

    assert {actual, []} = Group.build(base, [:title, :body])
    assert inspect(actual) == inspect(expected)
  end

  test "can group by nested field", %{base: base} do
    expected =
      from(p in Post,
        as: :post,
        left_join: a in assoc(p, :author),
        as: :post_author,
        group_by: [as(:post_author).publisher]
      )

    assert {actual, []} = Group.build(base, [[:author, :publisher]])
    assert inspect(actual) == inspect(expected)
  end

  test "can group by base and nested field", %{base: base} do
    expected =
      from(p in Post,
        as: :post,
        left_join: a in assoc(p, :author),
        as: :post_author,
        group_by: [as(:post).title],
        group_by: [as(:post_author).publisher]
      )

    assert {actual, []} = Group.build(base, [:title, [:author, :publisher]])
    assert inspect(actual) == inspect(expected)
  end

  test "can group by deeply nested field", %{base: base} do
    expected =
      from(p in Post,
        as: :post,
        left_join: a in assoc(p, :author),
        as: :post_author,
        left_join: u in assoc(a, :user),
        as: :post_author_user,
        group_by: [as(:post_author_user).name]
      )

    assert {actual, []} = Group.build(base, [[:author, :user, :name]])
    assert inspect(actual) == inspect(expected)
  end

  test "can group by has_many association field", %{base: base} do
    expected =
      from(p in Post,
        as: :post,
        left_join: c in assoc(p, :comments),
        as: :post_comments,
        group_by: [as(:post_comments).body]
      )

    assert {actual, []} = Group.build(base, [[:comments, :body]])
    assert inspect(actual) == inspect(expected)
  end

  test "handles non-existent field with selected_as", %{base: base} do
    expected = from(p in Post, as: :post, group_by: [selected_as(:fake)])
    assert {actual, []} = Group.build(base, [:fake])
    assert inspect(actual) == inspect(expected)
  end

  test "handles non-existent nested field with selected_as", %{base: base} do
    expected =
      from(p in Post,
        as: :post,
        left_join: a in assoc(p, :author),
        as: :post_author,
        group_by: [selected_as(:fake)]
      )

    assert {actual, []} = Group.build(base, [[:author, :fake]])
    assert inspect(actual) == inspect(expected)
  end

  test "returns error for bad association", %{base: base} do
    expected = from(p in Post, as: :post)

    assert {actual, [error]} = Group.build(base, [[:bad_association, :field]])
    assert inspect(actual) == inspect(expected)
    assert %{type: :group, path: [:bad_association]} = error
  end

  test "returns error and maintains load_path", %{base: base} do
    assert {_query, [error]} = Group.build(base, [[:bad_association, :field]], [:post, :comments, :user])
    assert %{type: :group, path: [:bad_association], load_path: [:user, :comments, :post]} = error
  end

  test "handles empty group list", %{base: base} do
    group = []
    assert {actual, []} = Group.build(base, group)
    assert inspect(actual) == inspect(elem(base, 0))
  end

  test "handles nil group parameter", %{base: base} do
    group = nil
    assert {actual, []} = Group.build(base, group)
    assert inspect(actual) == inspect(elem(base, 0))
  end

  test "handles group with existing joins in query", %{base: _base} do
    # Start with a query that already has joins
    base_with_joins = {
      from(p in Post, as: :post, left_join: a in assoc(p, :author), as: :post_author),
      []
    }

    expected =
      from(p in Post,
        as: :post,
        left_join: a in assoc(p, :author),
        as: :post_author,
        group_by: [as(:post_author).publisher]
      )

    group = [[:author, :publisher]]
    assert {actual, []} = Group.build(base_with_joins, group)
    assert inspect(actual) == inspect(expected)
  end

  test "handles mixed valid and invalid fields", %{base: base} do
    expected =
      from(p in Post,
        as: :post,
        group_by: [as(:post).title],
        group_by: [selected_as(:fake)]
      )

    group = [:title, :fake]
    assert {actual, []} = Group.build(base, group)
    assert inspect(actual) == inspect(expected)
  end

  test "handles duplicate field grouping", %{base: base} do
    expected = from(p in Post, as: :post, group_by: [as(:post).title])
    group = [:title, :title]
    assert {actual, []} = Group.build(base, group)
    assert inspect(actual) == inspect(expected)
  end

  test "can group by single field in list format", %{base: base} do
    expected = from(p in Post, as: :post, group_by: [as(:post).title])
    group = [:title]
    assert {actual, []} = Group.build(base, group)
    assert inspect(actual) == inspect(expected)
  end

  test "can group by multiple nested fields from different associations", %{base: base} do
    expected =
      from(p in Post,
        as: :post,
        left_join: a in assoc(p, :author),
        as: :post_author,
        left_join: c in assoc(p, :comments),
        as: :post_comments,
        group_by: [as(:post_author).publisher],
        group_by: [as(:post_comments).body]
      )

    group = [[:author, :publisher], [:comments, :body]]
    assert {actual, []} = Group.build(base, group)
    assert inspect(actual) == inspect(expected)
  end
end
