defmodule Mailseek.Gmail.Users do
  alias Mailseek.User.Gmail, as: GmailUser
  alias Mailseek.User.UserCategory
  alias Mailseek.User.GmailUserConnection
  alias Mailseek.Repo

  def get_user(user_id) do
    Repo.get_by!(GmailUser, user_id: user_id)
  end

  def create_user(attrs) do
    %GmailUser{}
    |> GmailUser.changeset(attrs)
    |> Repo.insert!()
  end

  def connect_users(attrs) do
    %GmailUserConnection{}
    |> GmailUserConnection.changeset(attrs)
    |> Repo.insert!(
      on_conflict: {:replace, [:expires_at, :updated_at]},
      conflict_target: [:from_user_id, :to_user_id]
    )
  end

  def upsert_user(user_id, attrs) do
    Repo.get_by(GmailUser, user_id: user_id)
    |> case do
      nil -> {:created, create_user(attrs)}
      user -> {:updated, update_user(user, attrs)}
    end
  end

  def update_user(user, attrs) do
    user
    |> GmailUser.update_changeset(attrs)
    |> Repo.update!()
  end

  def get_categories(user_id) do
    user_id
    |> get_user()
    |> Repo.preload(:categories)
    |> Map.fetch!(:categories)
  end

  def add_category(attrs) do
    %UserCategory{}
    |> UserCategory.changeset(attrs)
    |> Repo.insert!()
  end
end
