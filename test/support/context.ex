defmodule Quarry.Context do
  def list_posts(opts \\ []) do
    Quarry.Post
    |> Quarry.build(opts)
    |> Quarry.Repo.all()
  end

  def list_comments(opts \\ []) do
    Quarry.Comment
    |> Quarry.build(opts)
    |> Quarry.Repo.all()
  end
end
