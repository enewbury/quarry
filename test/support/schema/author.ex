defmodule Quarry.Author do
  use Ecto.Schema

  schema "authors" do
    field(:publisher, :string)

    belongs_to(:user, Quarry.User, foreign_key: :user_id)
    has_many(:posts, Quarry.Post)
  end
end
