defmodule Quarry.LoadTest do
  use ExUnit.Case
  doctest Quarry.Load
  alias Quarry.Load

  import Ecto.Query
  alias Quarry.{Comment, Post, Load}

  setup do
    %{base: {from(p in Post, as: :post), []}}
  end

  test "can preload belongs_to", %{base: base} do
    expected =
      from(
        p in Post,
        as: :post,
        join: a in assoc(p, :author),
        as: :post_author,
        preload: [author: a]
      )

    load = [:author]
    {actual, []} = Load.build(base, load)
    assert inspect(actual) == inspect(expected)
  end

  test "can preload nested belongs_to", %{base: base} do
    expected =
      from(
        p in Post,
        as: :post,
        join: a in assoc(p, :author),
        as: :post_author,
        join: u in assoc(a, :user),
        as: :post_author_user,
        preload: [author: {a, user: u}]
      )

    load = [author: :user]
    {actual, []} = Load.build(base, load)
    assert inspect(actual) == inspect(expected)
  end

  test "can preload has_many", %{base: base} do
    comments_query = from(c in Comment, as: :post_comment)

    expected =
      from(
        p in Post,
        as: :post,
        preload: [comments: ^comments_query]
      )

    load = [:comments]
    {actual, []} = Load.build(base, load)
    assert inspect(actual) == inspect(expected)
  end

  test "can preload belongs_to and has_many with nested belongs_to", %{base: base} do
    comments_query =
      from(
        c in Comment,
        as: :post_comment,
        join: u in assoc(c, :user),
        as: :post_comment_user,
        preload: [user: u]
      )

    expected =
      from(
        p in Post,
        as: :post,
        join: a in assoc(p, :author),
        as: :post_author,
        preload: [author: a],
        preload: [comments: ^comments_query]
      )

    load = [:author, comments: :user]
    {actual, []} = Load.build(base, load)
    assert inspect(actual) == inspect(expected)
  end

  test "can fully parameratize has_many preload", %{base: base} do
    comments_query =
      from(c in Comment,
        as: :post_comment,
        where: as(:post_comment).body == ^"comment",
        limit: ^1,
        offset: ^1
      )

    expected =
      from(
        p in Post,
        as: :post,
        preload: [comments: ^comments_query]
      )

    load = [comments: [filter: %{body: "comment"}, load: [], limit: 1, offset: 1]]
    {actual, []} = Load.build(base, load)
    assert inspect(actual) == inspect(expected)
  end
end
