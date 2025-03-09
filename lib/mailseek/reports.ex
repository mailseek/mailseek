defmodule Mailseek.Reports do
  alias Mailseek.User.Report
  alias Mailseek.Repo
  alias Mailseek.Gmail.Users

  import Ecto.Query

  def create_report(%{id: user_id}, attrs) do
    %Report{user_id: user_id}
    |> Report.changeset(attrs)
    |> Repo.insert!()
  end

  def list_reports(user_id) do
    user = Users.get_user(user_id)

    user_ids =
      user_id
      |> Users.get_connected_accounts()
      |> Enum.map(fn x -> x.id end)
      |> Enum.concat([user.id])

    Repo.all(from r in Report, where: r.user_id in ^user_ids, order_by: [desc: :inserted_at])
    |> Enum.sort_by(fn r ->
      {r.user_id, r.message_id, Map.get(r.payload, "order", 999)}
    end)
  end
end
