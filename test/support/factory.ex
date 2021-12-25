defmodule Quarry.Factory do
  use ExMachina.Ecto, repo: Quarry.Repo

  def post_factory do
    %Quarry.Post{
      title: sequence(:title, &"Post #{&1}"),
      body: "Post content",
      author: build(:author)
    }
  end

  def comment_factory do
    %Quarry.Comment{
      body: sequence("comment"),
      user: build(:user)
    }
  end

  def author_factory do
    %Quarry.Author{
      publisher: sequence("PublisherName"),
      user: build(:user)
    }
  end

  def user_factory do
    %Quarry.User{
      name: sequence("John Doe")
    }
  end
end
