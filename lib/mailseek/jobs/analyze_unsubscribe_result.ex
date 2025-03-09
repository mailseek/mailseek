defmodule Mailseek.Jobs.AnalyzeUnsubscribeResult do
  use Oban.Worker, queue: :ai_processing, max_attempts: 3

  alias Mailseek.LLM
  alias Mailseek.Reports
  alias Mailseek.Gmail.Users
  alias Mailseek.Gmail.Messages

  @model "deepseek-chat"
  @temperature 1.5

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "provider" => "gmail",
          "user_id" => user_id,
          "message_id" => message_id,
          "html" => html,
          "url" => url
        }
      }) do
    do_perform(user_id, message_id, html, url)
  end

  defp do_perform(user_id, message_id, html, url) do
    {:ok, %{response: response}} =
      LLM.process(%{
        type: :analyze_unsubscribe_result,
        temperature: @temperature,
        model: @model,
        html: html
      })

    dbg(response)

    user = Users.get_user(user_id)

    message = Messages.get_message(message_id)

    Reports.create_report(user, %{
      status: :success,
      message_id: message.id,
      type: "analyze_unsubscribe_result",
      payload: %{
        result: response,
        url: url,
        order: 999
      }
    })

    :ok
  end
end
