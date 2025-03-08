defmodule Mailseek.Jobs.CategorizeEmail do
  use Oban.Worker, queue: :ai_processing, max_attempts: 5

  alias Mailseek.LLM
  alias Mailseek.Gmail.Messages
  alias Mailseek.Gmail.Users
  require Logger

  @model "deepseek-chat"
  @temperature 0.5

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
    categories = Users.get_categories(user_id)

    {:ok, %{response: response}} =
      LLM.process(%{
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

    :ok
  end
end
