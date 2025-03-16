defmodule Mailseek.Jobs.AnalyzeUnsubscribePage do
  use Oban.Worker, queue: :ai_processing, max_attempts: 3

  alias Mailseek.LLM
  alias Mailseek.Jobs.ExecuteUnsubscribePageActions
  alias Mailseek.Reports
  alias Mailseek.Gmail.Users
  alias Mailseek.Gmail.Messages
  require Logger

  @model "gpt-4o"
  @temperature 1.5

  @impl Oban.Worker
  def perform(%Oban.Job{
        args:
          %{
            "provider" => "gmail",
            "user_id" => _user_id,
            "message_id" => _message_id,
            "html" => _html,
            "url" => _url
          } = args
      }) do
    do_perform(args)
  end

  defp do_perform(
         %{
           "user_id" => user_id,
           "message_id" => message_id,
           "html" => html,
           "url" => url
         } = args
       ) do
    {:ok, %{response: response}} =
      LLM.process(%{
        type: :analyze_unsubscribe_page,
        temperature: @temperature,
        model: @model,
        html: html
      })

    ExecuteUnsubscribePageActions.new(%{
      "provider" => "gmail",
      "user_id" => user_id,
      "message_id" => message_id,
      "url" => url,
      "instruction" => response
    })
    |> Oban.insert!()

    user = Users.get_user(user_id)
    message = Messages.get_message(message_id)

    Reports.create_report(user, %{
      status: :success,
      message_id: message.id,
      type: "analyze_unsubscribe_page",
      payload: %{
        order: Map.get(args, "order"),
        instructions: response,
        url: url
      }
    })

    :ok
  end

  @impl Oban.Worker
  def timeout(_job), do: :timer.seconds(60)
end
