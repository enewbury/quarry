defmodule Quarry.Repo.Migrations.AddAuthorsTable do
  use Ecto.Migration

  def change do
    create table("authors") do
      add :publisher, :string
      add :user_id, references(:users)
    end
  end
end
