defmodule Quarry.Repo.Migrations.AddLoginCountField do
  use Ecto.Migration

  def change do
    alter table("users") do
      add(:login_count, :integer)
    end
  end
end
