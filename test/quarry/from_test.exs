defmodule Quarry.FromTest do
  use ExUnit.Case
  doctest Quarry.From

  import Ecto.Query

  alias Quarry.{From, Post}

  test "can create from clause" do
    expected = from(p in Post, as: :post)
    {actual, []} = From.build({Post, []})
    assert inspect(expected) == inspect(actual)
  end

  test "can create from clause with binding prefix" do
    expected = from(p in Post, as: :author_post)
    {actual, []} = From.build({Post, []}, :author)

    assert inspect(expected) == inspect(actual)
  end
end
