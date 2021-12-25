{:ok, _} = Application.ensure_all_started(:ex_machina)
{:ok, _} = Quarry.Repo.start_link()

Ecto.Adapters.SQL.Sandbox.mode(Quarry.Repo, :manual)

ExUnit.start()
