defmodule Mailseek.Gmail.Users do
  alias Mailseek.User.Gmail, as: GmailUser
  alias Mailseek.Repo

  def get_user(user_id) do
    Repo.get_by!(GmailUser, user_id: user_id)
  end

  def create_user(attrs) do
    %GmailUser{}
    |> GmailUser.changeset(attrs)
    |> Repo.insert!()
  end

  def update_user(user, attrs) do
    user
    |> GmailUser.update_changeset(attrs)
    |> Repo.update!()
  end
end
