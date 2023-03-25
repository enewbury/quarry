defmodule Quarry.QueryStructTest do
  use ExUnit.Case
  doctest Quarry.Filter

  import Ecto.Query
  alias Quarry.{Author, Comment, Post, QueryStruct}

  describe "add_assoc/3" do
    test "can add when no assoc present" do
      base = from(p in Post, as: :post, join: a in assoc(p, :author), as: :post_author)
      expected = from([post_author: a] in base, preload: [author: a])
      actual = QueryStruct.add_assoc(base, [:author], :post_author)
      assert inspect(actual) == inspect(expected)
    end

    test "can add nested assoc" do
      base =
        from(p in Post,
          as: :post,
          join: a in assoc(p, :author),
          as: :post_author,
          join: u in assoc(a, :user),
          as: :post_author_user,
          preload: [author: a]
        )

      expected =
        from(p in Post,
          as: :post,
          join: a in assoc(p, :author),
          as: :post_author,
          join: u in assoc(a, :user),
          as: :post_author_user,
          preload: [author: {a, user: u}]
        )

      actual = QueryStruct.add_assoc(base, [:author, :user], :post_author_user)
      assert inspect(actual) == inspect(expected)
    end
  end

  describe "add_preload/3" do
    test "can prelaod when nothing joined" do
      base = from(p in Post, as: :post)
      subquery = from(c in Comment)
      expected = from(b in base, preload: [comments: ^subquery])
      actual = QueryStruct.add_preload(base, [:comments], subquery)
      assert actual == expected
    end

    test "doesn't use joined item when has_many association" do
      base = from(p in Post, as: :post, join: c in assoc(p, :comments), as: :post_comments)
      subquery = from(c in Comment)
      expected = from(b in base, preload: [comments: ^subquery])
      actual = QueryStruct.add_preload(base, [:comments], subquery)
      assert actual == expected
    end

    test "works for nested has_many association" do
      base =
        from(a in Author,
          as: :author,
          join: u in assoc(a, :user),
          as: :author_user,
          join: c in assoc(u, :comments),
          as: :author_user_comments
        )

      subquery = from(c in Comment)
      expected = from(b in base, preload: [user: [comments: ^subquery]])
      actual = QueryStruct.add_preload(base, [:user, :comments], subquery)
      assert actual == expected
    end
  end

  describe "with_from_as/2" do
    test "can add named binding to from" do
      without_line = fn query -> put_in(query, [:from, :line] |> Enum.map(&Access.key/1), nil) end

      expected = from(p in Post, as: :post) |> without_line.()

      actual = QueryStruct.with_from_as(from(p in Post), :post) |> without_line.()
      assert actual == expected
    end
  end

  describe "with_join_as/3" do
    test "can add named binding" do
      expected = from(p in Post, as: :post, join: a in assoc(p, :author), as: :post_author)

      actual =
        QueryStruct.with_join_as(
          from(p in Post, as: :post, join: a in assoc(p, :author)),
          :post_author,
          :author
        )

      assert inspect(expected) == inspect(actual)
    end

    test "can add named binding to join with other unnamed bindings" do
      expected =
        from(p in Post,
          join: a in assoc(p, :author),
          join: u in assoc(a, :user),
          as: :post_author_user
        )

      actual =
        QueryStruct.with_join_as(
          from(p in Post, join: a in assoc(p, :author), join: u in assoc(a, :user)),
          :post_author_user,
          :user
        )

      assert inspect(actual) == inspect(expected)
    end
  end
end
