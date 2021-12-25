defmodule Quarry.Comment do
  use Ecto.Schema

  schema "comments" do
    field(:body, :string)

    belongs_to(:post, Quarry.Post, foreign_key: :post_id)
    belongs_to(:user, Quarry.User, foreign_key: :user_id)
  end
end
