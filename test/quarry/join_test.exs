defmodule Quarry.JoinTest do
  use ExUnit.Case
  doctest Quarry.Join

  import Ecto.Query
  alias Quarry.{Join, Post}

  describe "with_join/3" do
    test "can add a join" do
      expected_query = from(p in Post, as: :post, left_join: a in assoc(p, :author), as: :post_author)
      {actual_query, join_binding} = Join.with_join(from(p in Post, as: :post), :post, :author)
      assert {inspect(expected_query), :post_author} == {inspect(actual_query), join_binding}
    end

    test "doesn't re-ad existing join" do
      expected_query = from(p in Post, as: :post, left_join: a in assoc(p, :author), as: :post_author)
      {actual_query, join_binding} = Join.with_join(expected_query, :post, :author)
      assert {inspect(expected_query), :post_author} == {inspect(actual_query), join_binding}
    end
  end

  describe "join_dependencies/2" do
    test "can add list of joins and return final binding" do
      expected_query =
        from(p in Post,
          as: :post,
          left_join: a in assoc(p, :author),
          as: :post_author,
          left_join: u in assoc(a, :user),
          as: :post_author_user
        )

      {actual_query, join_binding} =
        Join.join_dependencies(from(p in Post, as: :post), :post, [:user, :author])

      assert {inspect(expected_query), :post_author_user} == {inspect(actual_query), join_binding}
    end

    test "doesn't re-add existing join" do
      start_query = from(p in Post, as: :post, left_join: a in assoc(p, :author), as: :post_author)

      expected_query =
        from(p in Post,
          as: :post,
          left_join: a in assoc(p, :author),
          as: :post_author,
          left_join: u in assoc(a, :user),
          as: :post_author_user
        )

      {actual_query, join_binding} = Join.join_dependencies(start_query, :post, [:user, :author])

      assert {inspect(expected_query), :post_author_user} == {inspect(actual_query), join_binding}
    end
  end
end
