defmodule Quarry.Repo.Migrations.AddCommentsTable do
  use Ecto.Migration

  def change do
    create table("comments") do
      add(:body, :string)
      add(:user_id, references(:users))
      add(:post_id, references(:posts))
    end
  end
end
