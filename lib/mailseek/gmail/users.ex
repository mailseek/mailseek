defmodule Mailseek.Gmail.Users do
  alias Mailseek.User.Gmail, as: GmailUser
  alias Mailseek.User.UserCategory
  alias Mailseek.User.GmailUserConnection
  alias Mailseek.Repo

  import Ecto.Query

  def get_connected_accounts(user_id) do
    user_id
    |> get_user()
    |> Repo.preload(connected_accounts: :to_user)
    |> Map.fetch!(:connected_accounts)
    |> Enum.map(fn connection ->
      Map.fetch!(connection, :to_user)
    end)
  end

  def get_user(user_id) do
    Repo.get_by!(GmailUser, user_id: user_id)
  end

  def related_user_ids(user_id) do
    user_id
    |> get_connected_accounts()
    |> Enum.map(fn account ->
      account.user_id
    end)
    |> Enum.concat([user_id])
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

  def update_user(user_id, attrs) when is_binary(user_id) do
    user_id
    |> get_user()
    |> update_user(attrs)
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

  def categories_for_account(user_id) do
    user_id
    |> get_user()
    |> get_primary_account()
    |> Repo.preload(:categories)
    |> Map.fetch!(:categories)
  end

  def upsert_category(attrs) do
    %UserCategory{}
    |> UserCategory.changeset(attrs)
    |> Repo.insert!(
      on_conflict: {:replace, [:definition, :updated_at]},
      conflict_target: [:user_id, :name]
    )
  end

  def get_primary_account(%GmailUser{id: id} = self_user) do
    from(c in GmailUserConnection, where: c.to_user_id == ^id)
    |> Repo.all()
    |> List.first()
    |> case do
      nil -> self_user
      %{from_user_id: from_user_id} -> Repo.get!(GmailUser, from_user_id)
    end
  end
end
