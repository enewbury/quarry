defmodule Quarry.Repo.Migrations.AddInsertedAtToPosts do
  use Ecto.Migration

  def change do
    alter table("posts") do
      add(:inserted_at, :utc_datetime)
    end
  end
end
