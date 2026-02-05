defmodule Quarry.Post do
  use Ecto.Schema

  schema "posts" do
    field :title, :string
    field :body, :string
    field :inserted_at, :utc_datetime

    belongs_to :author, Quarry.Author, foreign_key: :author_id
    has_one :user, through: [:author, :user]
    has_many :comments, Quarry.Comment
  end
end
