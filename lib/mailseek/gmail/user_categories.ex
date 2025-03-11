defmodule Mailseek.Gmail.UserCategories do
  alias Mailseek.User.UserCategory.Settings
  alias Mailseek.Gmail.Users
  alias Mailseek.Repo

  import Ecto.Query

  @default_settings %{
    "archive_categorized_emails" => %{
      "type" => "boolean",
      "value" => true
    }
  }

  def save_category_settings(user_id, category_id, items) do
    %{id: id} = Users.get_user(user_id)

    items
    |> Enum.map(fn item ->
      %Settings{user_id: id, category_id: String.to_integer(category_id)}
      |> Settings.changeset(item)
      |> Repo.insert!(
        on_conflict: {:replace, [:value]},
        conflict_target: [:user_id, :category_id, :key]
      )
    end)
  end

  def get_category_settings(user_id, category_id) do
    %{id: id} = Users.get_user(user_id)

    from(c in Settings, where: c.user_id == ^id and c.category_id == ^category_id)
    |> Repo.all()
    |> then(fn x ->
      %{
        items: x
      }
    end)
    |> fill_empty_settings()
  end

  defp fill_empty_settings(%{items: items} = settings) do
    new_items =
      @default_settings
      |> Map.keys()
      |> Enum.with_index()
      |> Enum.map(fn {key, index} ->
        case Enum.find(items, fn item -> item.key == key end) do
          nil ->
            %{
              id: "#{DateTime.to_unix(DateTime.utc_now())}#{index}" |> String.to_integer(),
              key: key,
              value: Map.get(@default_settings, key)
            }

          existing_setting ->
            existing_setting
        end
      end)

    Map.put(settings, :items, new_items)
  end
end
