defmodule Mailseek.Repo do
  use Ecto.Repo,
    otp_app: :mailseek,
    adapter: Ecto.Adapters.Postgres
end
