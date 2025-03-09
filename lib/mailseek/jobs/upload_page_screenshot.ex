defmodule Mailseek.Jobs.UploadPageScreenshot do
  use Oban.Worker, queue: :file_upload, max_attempts: 3
  alias Mailseek.Reports
  alias Mailseek.Gmail.Users
  alias Mailseek.Gmail.Messages

  def perform(%Oban.Job{
        args:
          %{
            "path" => path,
            "key" => key,
            "bucket" => bucket,
            "user_id" => user_id,
            "message_id" => message_id
          } = args
      }) do
    {:ok, _response} =
      ExAws.S3.put_object(bucket, key, File.read!(path), [{:content_type, "image/png"}])
      |> ExAws.request()

    File.rm(path)

    user = Users.get_user(user_id)
    message = Messages.get_message(message_id)

    Reports.create_report(user, %{
      status: :success,
      message_id: message.id,
      type: bucket,
      payload: %{
        image_path: "#{bucket}/#{key}",
        order: Map.get(args, "order")
      }
    })

    :ok
  end
end
