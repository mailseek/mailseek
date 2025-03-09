defmodule Mailseek.LLM.Chain.FindUnsubscribeLink do
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
    |> LLMChain.add_message(Message.new_user!(html_message(context)))
  end

  defp definition_message(_context) do
    """
    You are an expert at analyzing HTML content from newsletters and other email campaigns.
    Your job is to analyze the HTML content and provide a link to the unsubscribe page.

    If there are no unsubscribe links, return in the JSON format:
    {
      "url": null
    }

    Return the link in JSON format:
    {
      "url": "https://example.com/unsubscribe"
    }
    """
  end

  defp html_message(%{html: html}) do
    """
    HTML:
    #{html}
    """
  end
end
