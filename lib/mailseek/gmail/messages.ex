defmodule Mailseek.Gmail.Messages do
  def build_message(%{
    id: id,
    internalDate: internal_date,
    labelIds: label_ids,
    payload: %{

    }
  }) do
    Mailseek.Client.Gmail.list_messages()
  end
end
