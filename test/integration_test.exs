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
               Context.list_posts(sort: [:title, author: :publisher], load: :author)
    end

    test "can sort desc" do
      insert(:post, title: "B")
      insert(:post, title: "A")
      insert(:post, title: "C")

      assert [%{title: "C"}, %{title: "B"}, %{title: "A"}] =
               Context.list_posts(sort: [desc: :title])
    end
  end
end
