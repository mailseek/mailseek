defmodule Mailseek.Jobs.FindUnsubscribeLink do
  use Oban.Worker, queue: :digest_email, max_attempts: 3

  alias Mailseek.Gmail.Messages
  alias Mailseek.Jobs.UnsubscribeFromEmails
  alias Mailseek.LLM
  require Logger

  @model "deepseek-chat"
  @temperature 0.5

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"provider" => "gmail", "user_id" => user_id, "message_id" => message_id}
      }) do
    do_perform(user_id, message_id)
  end

  defp do_perform(user_id, message_id) do
    %{html: html} = Messages.load_message(message_id, user_id)

    {:ok, %{response: response}} =
      LLM.process(%{
        type: :find_unsubscribe_link,
        temperature: @temperature,
        model: @model,
        html: html
      })

    unsubscribe_link = Map.get(response, "url")

    if unsubscribe_link do
      UnsubscribeFromEmails.new(%{
        "provider" => "gmail",
        "user_id" => user_id,
        "message_id" => message_id,
        "unsubscribe_link" => unsubscribe_link
      })
      |> Oban.insert!()
    else
      message_id
      |> Messages.get_message()
      |> Messages.update_message(%{status: "unsubscribe_link_not_found"})
    end

    :ok
  end
end
