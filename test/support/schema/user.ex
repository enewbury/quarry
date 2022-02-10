defmodule Quarry.User do
  use Ecto.Schema

  schema "users" do
    field(:name, :string)
    field(:login_count, :integer)
  end
end
