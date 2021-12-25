defmodule Quarry.Repo do
  use Ecto.Repo, otp_app: :quarry, adapter: Ecto.Adapters.Postgres
end
