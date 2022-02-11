defmodule Quarry.FilterTest do
  use ExUnit.Case
  doctest Quarry.Filter

  import Ecto.Query
  alias Quarry.{Post, Filter}

  setup do
    %{base: from(p in Post, as: :post)}
  end

  test "can filter by top level props", %{base: base} do
    expected =
      from(
        p in Post,
        as: :post,
        where: as(:post).body == ^"body",
        where: as(:post).title == ^"title"
      )

    filter = %{title: "title", body: "body"}
    assert actual = Filter.build(base, filter)
    assert inspect(actual) == inspect(expected)
  end

  test "ignores bad top level props", %{base: base} do
    filter = %{bad: "prop", fake: ["option"], fake2: %{name: "John"}}
    assert actual = Filter.build(base, filter)
    assert inspect(actual) == inspect(base)
  end

  test "can filter by joined props", %{base: base} do
    expected =
      from(
        p in Post,
        as: :post,
        join: a in assoc(p, :author),
        as: :post_author,
        where: as(:post_author).publisher == ^"publisher"
      )

    filter = %{author: %{publisher: "publisher"}}
    assert actual = Filter.build(base, filter)
    assert inspect(actual) == inspect(expected)
  end

  test "ignores bad nested props", %{base: base} do
    expected = from(p in Post, as: :post)
    filter = %{author: %{bad: "badprop"}}
    actual = Filter.build(base, filter)
    assert inspect(actual) == inspect(expected)
  end

  test "can filter at multiple levels without duplicate join", %{base: base} do
    expected =
      from(
        p in Post,
        as: :post,
        join: a in assoc(p, :author),
        as: :post_author,
        join: u in assoc(a, :user),
        as: :post_author_user,
        where: as(:post_author).publisher == ^"publisher",
        where: as(:post_author_user).name == ^"john"
      )

    filter = %{author: %{publisher: "publisher", user: %{name: "john"}}}
    assert actual = Filter.build(base, filter)
    assert inspect(actual) == inspect(expected)
  end

  test "can filter with multiple options", %{base: base} do
    expected =
      from(
        p in Post,
        as: :post,
        join: a in assoc(p, :author),
        as: :post_author,
        join: u in assoc(a, :user),
        as: :post_author_user,
        where: as(:post_author).publisher in ^["publisher1", "publisher2"],
        where: as(:post_author_user).name == ^"john"
      )

    filter = %{author: %{publisher: ["publisher1", "publisher2"], user: %{name: "john"}}}
    actual = Filter.build(base, filter)
    assert inspect(actual) == inspect(expected)
  end

  test "can filter on has_many relation", %{base: base} do
    expected =
      from(p in Post,
        as: :post,
        join: c in assoc(p, :comments),
        as: :post_comments,
        where: as(:post_comments).body == ^"comment"
      )

    filter = %{comments: %{body: "comment"}}
    actual = Filter.build(base, filter)
    assert inspect(actual) == inspect(expected)
  end

  test "can filter by less than" do
    expected =
      from(p in Post,
        as: :post,
        join: a in assoc(p, :author),
        as: :post_author,
        join: u in assoc(a, :user),
        as: :post_author_user,
        where: as(:post_author_user).login_count < ^1
      )

    actual = Quarry.build(Post, filter: %{author: %{user: %{login_count: {:lt, 1}}}})
    assert inspect(actual) == inspect(expected)
  end

  test "can filter by greater than" do
    expected =
      from(p in Post,
        as: :post,
        join: a in assoc(p, :author),
        as: :post_author,
        join: u in assoc(a, :user),
        as: :post_author_user,
        where: as(:post_author_user).login_count > ^1
      )

    actual = Quarry.build(Post, filter: %{author: %{user: %{login_count: {:gt, 1}}}})
    assert inspect(actual) == inspect(expected)
  end

  test "can filter by greater than or equal" do
    expected =
      from(p in Post,
        as: :post,
        join: a in assoc(p, :author),
        as: :post_author,
        join: u in assoc(a, :user),
        as: :post_author_user,
        where: as(:post_author_user).login_count >= ^1
      )

    actual = Quarry.build(Post, filter: %{author: %{user: %{login_count: {:gte, 1}}}})
    assert inspect(actual) == inspect(expected)
  end

  test "can filter by less than or equal" do
    expected =
      from(p in Post,
        as: :post,
        join: a in assoc(p, :author),
        as: :post_author,
        join: u in assoc(a, :user),
        as: :post_author_user,
        where: as(:post_author_user).login_count <= ^1
      )

    actual = Quarry.build(Post, filter: %{author: %{user: %{login_count: {:lte, 1}}}})
    assert inspect(actual) == inspect(expected)
  end

  test "can filter by starts with" do
    expected = from(p in Post, as: :post, where: ilike(as(:post).title, ^"How to%"))
    actual = Quarry.build(Post, filter: %{title: {:starts_with, "How to"}})
    assert inspect(actual) == inspect(expected)
  end

  test "can filter by ends with" do
    expected = from(p in Post, as: :post, where: ilike(as(:post).title, ^"%learn vim"))
    actual = Quarry.build(Post, filter: %{title: {:ends_with, "learn vim"}})
    assert inspect(actual) == inspect(expected)
  end

  test "can filter using map style" do
    expected = from(p in Post, as: :post, where: ilike(as(:post).title, ^"%learn vim"))
    actual = Quarry.build(Post, filter: %{title: %{op: :ends_with, value: "learn vim"}})
    assert inspect(actual) == inspect(expected)
  end
end
