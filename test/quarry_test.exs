defmodule QuarryTest do
  use ExUnit.Case
  doctest Quarry
  alias Quarry
  alias Quarry.Post

  import Ecto.Query

  test "can limit results" do
    expected = from(p in Post, as: :post, limit: ^1)
    actual = Quarry.build(Post, limit: 1)
    assert inspect(expected) == inspect(actual)
  end

  test "can offset limit" do
    expected = from(p in Post, as: :post, limit: ^1, offset: ^1)
    actual = Quarry.build(Post, limit: 1, offset: 1)
    assert inspect(expected) == inspect(actual)
  end

  test "can filter and preload belongs_to without double join" do
    expected =
      from(
        p in Post,
        as: :post,
        join: a in assoc(p, :author),
        as: :post_author,
        where: as(:post_author).publisher == ^"publisher",
        preload: [author: a]
      )

    filter = %{author: %{publisher: "publisher"}}
    preloads = [:author]
    actual = Quarry.build(Post, filter: filter, preloads: preloads)
    assert inspect(actual) == inspect(expected)
  end
end
