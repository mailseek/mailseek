defmodule Mailseek.LLM.Chain.Categorize do
  alias LangChain.Message
  alias LangChain.Chains.LLMChain
  alias Mailseek.LLM.Model

  require Logger

  def chain(context = %{}) do
    context
    |> base_chain()
  end

  def build_response({:ok, value}, context = %{}) when is_binary(value) do
    {:ok,
     %{
       response: Jason.decode!(value),
       model: context.model,
       temperature: context.temperature
     }}
  end

  defp base_chain(context = %{temperature: temperature, model: model}) do
    %{
      llm: Model.parse(model, %{temperature: temperature, json_response: true}),
      custom_context: context
    }
    |> LLMChain.new!()
    |> LLMChain.add_message(Message.new_system!(definition_message(context)))
    |> LLMChain.add_message(Message.new_user!(email_message(context)))
  end

  defp definition_message(context) do
    categories =
      context.categories
      |> Enum.map(fn x ->
        "- #{x.name}: #{x.definition || "No definition provided"}"
      end)
      |> Enum.join("\n")

    """
    You are an expert at categorizing emails. Your job is to categorize the email by one of the following categories, using the name of the category and its definition(if available):

    Categories:
    #{categories}

    If no categories are present, set category to "Other" and provide a reason for the categorization.
    If no category is a good fit, set category to Uncategorized and provide a reason why it didnt fit into any of the categories.

    You should return result in JSON format:
    {
      "category": "Work",
      "reason": "The email is related to work",
      "summary": "Summary of the content of the email",
      "need_action": false // whether the email needs an action/reply
    }
    """
  end

  defp email_message(%{email: %{from: from, subject: subject, body: body}}) do
    """
    Email payload:
    From: #{from}
    Subject: #{subject}
    Body: #{body}
    """
  end
end
