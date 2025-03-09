defmodule Mailseek.LLM.Chain.AnalyzeUnsubscribeResult do
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
    You are an expert at analyzing HTML content from unsubscribe pages for newsletter and other email campaigns.
    Your job is to analyze the HTML content and provide a summary of what happens on the page.
    Take into account that the page you see is the result of the actions you took to unsuscribe from the email campaign.

    You should return JSON result in this format:
    {
      "success": true, // true if the unsubscribe was successful, false otherwise
      "reason": "reason why the unsubscribe was successful or not and what steps are required or not. be expressive and detailed."
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
