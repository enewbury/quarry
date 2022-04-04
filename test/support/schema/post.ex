defmodule Quarry.Post do
  use Ecto.Schema

  schema "posts" do
    field :title, :string
    field :body, :string

    belongs_to :author, Quarry.Author, foreign_key: :author_id
    has_many :comments, Quarry.Comment
  end
end
