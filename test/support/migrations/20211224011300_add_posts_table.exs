defmodule Quarry.Repo.Migrations.AddPostsTable do
  use Ecto.Migration

  def change do
    create table("posts") do
      add :title, :string
      add :body, :string
      add :author_id, references(:authors)
    end
  end
end
