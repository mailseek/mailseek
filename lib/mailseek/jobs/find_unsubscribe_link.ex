defmodule Mailseek.Jobs.FindUnsubscribeLink do
  use Oban.Worker, queue: :digest_email, max_attempts: 3

  alias Mailseek.Gmail.Messages
  alias Mailseek.Jobs.UnsubscribeFromEmails
  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"provider" => "gmail", "user_id" => user_id, "message_id" => message_id}
      }) do
    do_perform(user_id, message_id)
  end

  defp do_perform(user_id, message_id) do
    %{html: html} = Messages.load_message(message_id, user_id)

    unsubscribe_link =
      html
      |> Floki.find("a[href*='unsubscribe']")
      |> dbg()
      |> Floki.attribute("href")
      |> dbg()
      |> List.first()

    if unsubscribe_link do
      # add job for unsubscribe for this link
      UnsubscribeFromEmails.new(%{
        "provider" => "gmail",
        "user_id" => user_id,
        "message_id" => message_id,
        "unsubscribe_link" => unsubscribe_link
      })
      |> Oban.insert!()
    end

    :ok
  end
end
