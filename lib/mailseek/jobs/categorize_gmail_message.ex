defmodule Mailseek.Jobs.CategorizeEmail do
  use Oban.Worker, queue: :ai_processing, max_attempts: 5

  alias Mailseek.LLM
  alias Mailseek.Gmail.Messages
  alias Mailseek.Gmail.Users
  alias Mailseek.Client.Gmail
  alias Mailseek.Notifications
  alias Mailseek.Repo
  alias Mailseek.Gmail.TokenManager
  require Logger

  @model "deepseek-chat"
  @temperature 1.5

  @impl true
  def perform(%{
        args: %{"provider" => "gmail", "message_id" => _, "email" => %{}, "user_id" => _} = args
      }) do
    do_perform(args)
  end

  defp do_perform(%{
         "provider" => "gmail",
         "message_id" => message_id,
         "user_id" => user_id,
         "email" => %{
           "from" => from,
           "to" => to,
           "subject" => subject,
           "body" => body
         }
       }) do
    categories = Users.categories_for_account(user_id)

    primary_user =
      %{} =
      user_id
      |> Users.get_user()
      |> Users.get_primary_account()

    {:ok, %{response: response}} =
      LLM.process(%{
        type: :categorize,
        temperature: @temperature,
        model: @model,
        categories: Enum.map(categories, &%{id: &1.id, name: &1.name, definition: &1.definition}),
        email: %{
          from: from,
          to: to,
          subject: subject,
          body: body
        }
      })

    category_id =
      case Enum.find(categories, fn category ->
             category.name == Map.fetch!(response, "category")
           end) do
        nil ->
          nil

        category ->
          category.id
      end

    Logger.info(
      "Categorizing message #{message_id} with category #{category_id}: #{inspect(response)}"
    )

    {:ok, message} =
      Repo.transaction(fn ->
        if not is_nil(category_id) do
          {:ok, token} = TokenManager.get_access_token(user_id)

          {:ok, _} = Gmail.archive_message(token, message_id)
        end

        message_id
        |> Messages.get_message()
        |> Messages.update_message(%{
          category_id: category_id,
          summary: Map.fetch!(response, "summary"),
          need_action: Map.fetch!(response, "need_action"),
          reason: Map.fetch!(response, "reason"),
          status: "processed",
          model: @model,
          temperature: @temperature
        })
      end)

    Notifications.notify("emails:all", {
      :email_processed,
      %{
        message: message
      },
      primary_user.user_id
    })
  end
end
