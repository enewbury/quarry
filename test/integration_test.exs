defmodule Quarry.IntegrationTest do
  use Quarry.DataCase
  doctest Quarry

  import Quarry.Factory
  alias Quarry.Context

  test "returns empty when entities" do
    assert Context.list_posts() == []
  end

  test "returns entities" do
    [%{id: id1}, %{id: id2}] = insert_list(2, :post)
    result = Context.list_posts()
    assert length(result) == 2
    assert [%{id: ^id1}, %{id: ^id2}] = result
  end

  describe "load" do
    test "load data" do
      %{id: id, author: %{id: author_id, user: %{id: user_id}}} =
        insert(:post, author: insert(:author, user: insert(:user)))

      load = [author: [user: []]]

      assert [%{id: ^id, author: %{id: ^author_id, user: %{id: ^user_id}}}] =
               Context.list_posts(load: load)
    end

    test "load has_many relationship" do
      post = insert(:post)
      %{id: comment_id} = insert(:comment, post: post)

      load = [:comments]

      assert [%{comments: [%{id: ^comment_id}]}] = Context.list_posts(load: load)
    end

    test "load nested has_many relationship" do
      user = insert(:user)
      author = insert(:author, user: user)
      post = insert(:post, author: author)
      insert(:comment, post: post, user: user)

      load = [:user, post: [author: [posts: :author]]]

      assert [%{user: _user, post: %{author: %{posts: [%{author: _author}]}}}] =
               Context.list_comments(load: load)
    end
  end

  describe "filter" do
    test "filter top level attribute" do
      %{id: id, title: title} = insert(:post, title: "title 1")
      insert(:post, title: "title 2")

      filter = %{title: title}
      assert [%{id: ^id, title: ^title}] = Context.list_posts(filter: filter)
    end

    test "filter nested attribute" do
      %{id: id, author: %{publisher: publisher}} = insert(:post, author: insert(:author))
      insert(:post, author: insert(:author))

      filter = %{author: %{publisher: publisher}}

      assert [%{id: ^id, author: %{publisher: ^publisher}}] =
               Context.list_posts(filter: filter, load: [:author])
    end

    test "filter has_many attribute" do
      %{post: %{id: post_id}} = insert(:comment, body: "comment", post: insert(:post))
      insert(:comment, body: "other_comment", post: insert(:post))

      filter = %{comments: %{body: "comment"}}

      assert [%{id: ^post_id, comments: [%{body: "comment"}]}] =
               Context.list_posts(filter: filter, load: :comments)
    end

    test "limit has_many attribute" do
      post = insert(:post)
      insert(:comment, body: "comment1", post: post)
      insert(:comment, body: "comment2", post: post)

      assert [%{comments: [%{body: "comment2"}]}] =
               Context.list_posts(load: [comments: [limit: 1, offset: 1]])
    end
  end

  describe "select" do
    test "can select with basic function" do
      %{id: id, title: title} = insert(:post, title: "Hello World")
      insert(:post, title: "another post")

      select = [:id, :title, %{field: [:title], as: :title_upper, function: :upper}]
      result = Context.list_posts(select: select)

      # Find the specific post we created
      our_post = Enum.find(result, &(&1.id == id))
      assert our_post == %{id: id, title: title, title_upper: "HELLO WORLD"}

      # Verify we have the expected number of posts
      assert length(result) == 2
    end

    test "can select with nested function" do
      user = insert(:user, name: "john doe")
      author = insert(:author, user: user)
      %{id: id} = insert(:post, author: author)
      insert(:post, author: insert(:author, user: insert(:user, name: "jane smith")))

      select = [:id, %{field: [:author, :user, :name], as: :author_name_lower, function: :lower}]
      result = Context.list_posts(select: select)

      # Find the specific post we created
      our_post = Enum.find(result, &(&1.id == id))
      assert our_post == %{id: id, author_name_lower: "john doe"}

      # Verify we have the expected number of posts
      assert length(result) == 2
    end

    test "can mix regular fields and functions" do
      user = insert(:user, name: "test user")
      author = insert(:author, user: user, publisher: "test publisher")
      %{id: id, title: title} = insert(:post, author: author, title: "Test Post")

      select = [:id, :title, [:author, :publisher], %{field: [:author, :user, :name], as: :author_name_upper, function: :upper}]
      result = Context.list_posts(select: select)

      # Find the specific post we created
      our_post = Enum.find(result, &(&1.id == id))
      assert our_post == %{id: id, title: title, publisher: "test publisher", author_name_upper: "TEST USER"}

      # Verify we have at least one post
      assert length(result) >= 1
    end

    test "can select with date_trunc functions" do
      # Skip this test for SQLite as it doesn't support date_trunc
      # Check if we're using SQLite by looking at the adapter
      repo_config = Application.get_env(:quarry, Quarry.Repo)
      if repo_config[:adapter] == Ecto.Adapters.SQLite3 do
        # This is SQLite, skip the test
        :ok
      else
        now = DateTime.utc_now()
        %{id: id, inserted_at: inserted_at} = insert(:post, inserted_at: now)
        insert(:post, inserted_at: DateTime.add(now, 3600, :second))  # 1 hour later

        select = [
          :id, :title,
          %{field: [:inserted_at], as: :day_truncated, function: :date_trunc_day},
          %{field: [:inserted_at], as: :month_truncated, function: :date_trunc_month}
        ]
        result = Context.list_posts(select: select)

        # Find the specific post we created
        our_post = Enum.find(result, &(&1.id == id))
        assert our_post != nil

        # Verify the truncated dates are correct
        # PostgreSQL date_trunc returns actual date/timestamp values, not strings
        expected_day = DateTime.truncate(inserted_at, :second) |> DateTime.to_date()
        expected_month = DateTime.truncate(inserted_at, :second) |> DateTime.to_date() |> Date.beginning_of_month()

        # date_trunc('day', ?) returns a date value
        assert our_post.day_truncated == expected_day
        # date_trunc('month', ?) returns the first day of the month as a date value
        assert our_post.month_truncated == expected_month

        # Verify we have the expected number of posts
        assert length(result) == 2
      end
    end
  end

  describe "sort" do
    test "can order by top level attribute" do
      insert(:post, title: "B")
      insert(:post, title: "A")
      insert(:post, title: "C")

      assert [%{title: "A"}, %{title: "B"}, %{title: "C"}] = Context.list_posts(sort: :title)
    end

    test "can order by multiple top level attribute" do
      insert(:post, title: "B", body: "A")
      insert(:post, title: "A", body: "B")
      insert(:post, title: "A", body: "C")

      assert [%{title: "A", body: "B"}, %{title: "A"}, %{title: "B"}] =
               Context.list_posts(sort: [:title, :body])
    end

    test "can order by nested attribute" do
      insert(:post, title: "B", author: insert(:author, publisher: "B"))
      insert(:post, title: "A", author: insert(:author, publisher: "A"))
      insert(:post, title: "C", author: insert(:author, publisher: "C"))

      assert [%{title: "A"}, %{title: "B"}, %{title: "C"}] =
               Context.list_posts(sort: [[:author, :publisher]])
    end

    test "can order multiple top and nested attribute" do
      insert(:post, title: "B", author: insert(:author, publisher: "A"))
      insert(:post, title: "A", author: insert(:author, publisher: "B"))
      insert(:post, title: "A", author: insert(:author, publisher: "C"))

      assert [%{title: "A", author: %{publisher: "B"}}, %{title: "A"}, %{title: "B"}] =
               Context.list_posts(sort: [:title, [:author, :publisher]], load: :author)
    end

    test "can sort desc" do
      insert(:post, title: "B")
      insert(:post, title: "A")
      insert(:post, title: "C")

      assert [%{title: "C"}, %{title: "B"}, %{title: "A"}] =
               Context.list_posts(sort: [desc: :title])
    end

    test "can sort by select_as field" do
      insert(:post, title: "b")
      insert(:post, title: "A")
      insert(:post, title: "c")

      # Sort by the UPPER(title) field using select_as
      {query, _errors} = Quarry.build(
        Quarry.Post, select: [%{field: [:title], as: :title_upper, function: :upper}], sort: [asc: :title_upper]
      )


      result = Quarry.Repo.all(query)

      # Should be sorted by uppercase values: A, b, c
      assert [%{title_upper: "A"}, %{title_upper: "B"}, %{title_upper: "C"}] = result
    end
  end
end
