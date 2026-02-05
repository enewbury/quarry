defmodule QuarryTest do
  use ExUnit.Case
  doctest Quarry
  alias Quarry
  alias Quarry.Post

  import Ecto.Query

  describe "build!/2" do
    test "can limit results" do
      expected = from(p in Post, as: :post, limit: ^1)
      actual = Quarry.build!(Post, limit: 1)
      assert inspect(expected) == inspect(actual)
    end

    test "can offset limit" do
      expected = from(p in Post, as: :post, limit: ^1, offset: ^1)
      actual = Quarry.build!(Post, limit: 1, offset: 1)
      assert inspect(expected) == inspect(actual)
    end

    test "can filter and preload belongs_to without double join" do
      expected =
        from(
          p in Post,
          as: :post,
          left_join: a in assoc(p, :author),
          as: :post_author,
          where: as(:post_author).publisher == ^"publisher",
          preload: [author: a]
        )

      filter = %{author: %{publisher: "publisher"}}
      load = [:author]
      actual = Quarry.build!(Post, filter: filter, load: load)
      assert inspect(actual) == inspect(expected)
    end
  end

  describe "build/2" do
    test "can return errors when ignored bad filter field" do
      expected = from(p in Post, as: :post)
      {actual, [error]} = Quarry.build(Post, filter: %{fake: "value"})
      assert inspect(expected) == inspect(actual)
      assert %{type: :filter, path: [:fake], message: message} = error

      assert message ==
               "Quarry couldn't find field \"fake\" on Ecto schema \"Elixir.Quarry.Post\""
    end
  end
end
