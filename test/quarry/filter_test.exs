defmodule Quarry.FilterTest do
  use ExUnit.Case
  doctest Quarry.Filter

  import Ecto.Query
  alias Quarry.{Post, Filter}

  setup do
    %{base: {from(p in Post, as: :post), []}}
  end

  test "can filter by top level props", %{base: base} do
    expected =
      from(
        p in Post,
        as: :post,
        where: as(:post).title == ^"title",
        where: as(:post).body == ^"body"
      )

    filter = %{title: "title", body: "body"}
    assert {actual, []} = Filter.build(base, filter)
    assert inspect(actual) == inspect(expected)
  end

  test "ignores bad top level props, and returns error", %{base: base} do
    filter = %{bad: "prop", fake: ["option"], fake2: %{name: "John"}}
    {actual, errors} = Filter.build(base, filter)

    assert inspect(actual) == inspect(elem(base, 0))

    assert [%{path: [:bad]}, %{path: [:fake]}, %{path: [:fake2]}] =
             Enum.sort_by(errors, & &1.message)
  end

  test "can filter by joined props", %{base: base} do
    expected =
      from(
        p in Post,
        as: :post,
        left_join: a in assoc(p, :author),
        as: :post_author,
        where: as(:post_author).publisher == ^"publisher"
      )

    filter = %{author: %{publisher: "publisher"}}
    assert {actual, []} = Filter.build(base, filter)
    assert inspect(actual) == inspect(expected)
  end

  test "ignores bad nested props, and returns error", %{base: base} do
    expected = from(p in Post, as: :post)
    filter = %{author: %{bad: "badprop"}}
    {actual, [error]} = Filter.build(base, filter)
    assert inspect(actual) == inspect(expected)
    assert %{path: [:author, :bad]} = error
  end

  test "returns passed in load_path on errors", %{base: base} do
    {_, [error]} = Filter.build(base, %{author: %{bad: "test"}}, [:post, :comments])
    assert %{type: :filter, path: [:author, :bad], load_path: [:comments, :post]} = error
  end

  test "can filter at multiple levels without duplicate join", %{base: base} do
    expected =
      from(
        p in Post,
        as: :post,
        left_join: a in assoc(p, :author),
        as: :post_author,
        left_join: u in assoc(a, :user),
        as: :post_author_user,
        where: as(:post_author_user).name == ^"john",
        where: as(:post_author).publisher == ^"publisher"
      )

    filter = %{author: %{publisher: "publisher", user: %{name: "john"}}}
    assert {actual, []} = Filter.build(base, filter)
    assert inspect(actual) == inspect(expected)
  end

  test "can filter with multiple options", %{base: base} do
    expected =
      from(
        p in Post,
        as: :post,
        left_join: a in assoc(p, :author),
        as: :post_author,
        left_join: u in assoc(a, :user),
        as: :post_author_user,
        where: as(:post_author_user).name == ^"john",
        where: as(:post_author).publisher in ^["publisher1", "publisher2"]
      )

    filter = %{author: %{publisher: ["publisher1", "publisher2"], user: %{name: "john"}}}
    {actual, []} = Filter.build(base, filter)
    assert inspect(actual) == inspect(expected)
  end

  test "can filter on has_many relation", %{base: base} do
    expected =
      from(p in Post,
        as: :post,
        left_join: c in assoc(p, :comments),
        as: :post_comments,
        where: as(:post_comments).body == ^"comment"
      )

    filter = %{comments: %{body: "comment"}}
    {actual, []} = Filter.build(base, filter)
    assert inspect(actual) == inspect(expected)
  end

  test "can filter by less than", %{base: base} do
    expected =
      from(p in Post,
        as: :post,
        left_join: a in assoc(p, :author),
        as: :post_author,
        left_join: u in assoc(a, :user),
        as: :post_author_user,
        where: as(:post_author_user).login_count < ^1
      )

    {actual, []} = Filter.build(base, %{author: %{user: %{login_count: {:lt, 1}}}})
    assert inspect(actual) == inspect(expected)
  end

  test "can filter by greater than", %{base: base} do
    expected =
      from(p in Post,
        as: :post,
        left_join: a in assoc(p, :author),
        as: :post_author,
        left_join: u in assoc(a, :user),
        as: :post_author_user,
        where: as(:post_author_user).login_count > ^1
      )

    {actual, []} = Filter.build(base, %{author: %{user: %{login_count: {:gt, 1}}}})
    assert inspect(actual) == inspect(expected)
  end

  test "can filter by greater than or equal", %{base: base} do
    expected =
      from(p in Post,
        as: :post,
        left_join: a in assoc(p, :author),
        as: :post_author,
        left_join: u in assoc(a, :user),
        as: :post_author_user,
        where: as(:post_author_user).login_count >= ^1
      )

    {actual, []} = Filter.build(base, %{author: %{user: %{login_count: {:gte, 1}}}})
    assert inspect(actual) == inspect(expected)
  end

  test "can filter by less than or equal", %{base: base} do
    expected =
      from(p in Post,
        as: :post,
        left_join: a in assoc(p, :author),
        as: :post_author,
        left_join: u in assoc(a, :user),
        as: :post_author_user,
        where: as(:post_author_user).login_count <= ^1
      )

    {actual, []} = Filter.build(base, %{author: %{user: %{login_count: {:lte, 1}}}})
    assert inspect(actual) == inspect(expected)
  end

  test "can filter by starts with", %{base: base} do
    expected = from(p in Post, as: :post, where: ilike(as(:post).title, ^"How to%"))
    {actual, []} = Filter.build(base, %{title: {:starts_with, "How to"}})
    assert inspect(actual) == inspect(expected)
  end

  test "can filter by ends with", %{base: base} do
    expected = from(p in Post, as: :post, where: ilike(as(:post).title, ^"%learn vim"))
    {actual, []} = Filter.build(base, %{title: {:ends_with, "learn vim"}})
    assert inspect(actual) == inspect(expected)
  end

  test "can filter for nil field (simple value)", %{base: base} do
    expected = from(p in Post, as: :post, where: is_nil(as(:post).inserted_at))
    {actual, []} = Filter.build(base, %{inserted_at: nil})
    assert inspect(actual) == inspect(expected)
  end

  test "can filter for nil field (explicit :eq)", %{base: base} do
    expected = from(p in Post, as: :post, where: is_nil(as(:post).inserted_at))
    {actual, []} = Filter.build(base, %{inserted_at: {:eq, nil}})
    assert inspect(actual) == inspect(expected)
  end

  test "can filter for not nil field (:neq nil)", %{base: base} do
    expected = from(p in Post, as: :post, where: not is_nil(as(:post).inserted_at))
    {actual, []} = Filter.build(base, %{inserted_at: {:neq, nil}})
    assert inspect(actual) == inspect(expected)
  end

  test "can filter by not equal", %{base: base} do
    expected = from(p in Post, as: :post, where: as(:post).title != ^"other")
    {actual, []} = Filter.build(base, %{title: {:neq, "other"}})
    assert inspect(actual) == inspect(expected)
  end
end
