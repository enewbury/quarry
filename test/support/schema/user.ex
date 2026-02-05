defmodule Quarry.User do
  use Ecto.Schema

  schema "users" do
    field :name, :string
    field :login_count, :integer

    has_many :authors, Quarry.Author
    has_many :posts, through: [:authors, :posts]
  end
end
