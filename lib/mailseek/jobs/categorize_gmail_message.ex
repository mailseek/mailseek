defmodule Mailseek.Jobs.CategorizeEmail do
  use Oban.Worker, queue: :ai_processing, max_attempts: 5

  alias Mailseek.LLM
  # alias Mailseek.Gmail.Messages

  require Logger

  @impl true
  def perform(%{args: %{"provider" => "gmail", "message_id" => _, "email" => %{}} = args}) do
    do_perform(args)
  end

  defp do_perform(%{
         "provider" => "gmail",
         "message_id" => message_id,
         "email" => %{
           "from" => from,
           "to" => to,
           "subject" => subject,
           "body" => body
         }
       }) do
    {:ok, %{response: response}} =
      LLM.process(%{
        temperature: 0.5,
        model: "deepseek-chat",
        categories: [
          %{
            name: "Work",
            definition: "Emails related to work"
          },
          %{
            name: "Allegro",
            definition: "Orders, invoices and other emails related to Allegro"
          },
          %{
            name: "From Friends",
            definition: "Emails from friends and family"
          }
        ],
        email: %{
          from: from,
          to: to,
          subject: subject,
          body: body
        }
      })
      |> dbg()

    dbg({"Processed", message_id, response})

    :ok
  end
end
