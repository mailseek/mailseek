defmodule Mailseek.LLM.Chain.AnalyzeUnsubscribePage do
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
    Your job is to analyze the HTML content and provide a summary of actions that need to be taken to unsubscribe from the email campaign (if any).
    Actions should be sequential, so if the page has a form, you should fill it out, then click the button, then check the checkbox, etc.

    Possible actions:
    - If input has to be filled out, come up with a value for the input field and add this json object to the result:
    {
      "action": "fill_out",
      "selector": "selector of the input field to find an element",
      "value": "value to be inserted"
    }
    - If button has to be clicked, add this json object to the result:
    {
      "action": "click",
      "selector": "selector of the button to find an element",
    }
    - If input with type checkbox has to be checked, add this json object to the result:
    {
      "action": "check",
      "selector": "class name of the checkbox to find an element",
    }
    - If input with type checkbox has to be unchecked, add this json object to the result:
    {
      "action": "uncheck",
      "selector": "selector of the checkbox to find an element",
    }
    - If no action is needed, set "action_needed" to false and return empty array for "actions".

    You should return result in JSON format:
    {
      "reason": "reason why actions needed or not needed and what should be done and why",
      "action_needed": true/false, // whether the page needs an action in order to unsubscribe (for example clicking a button or filling out a form)
      "actions": [
        {
          "action": "fill_out", // action to be taken
          "selector": "selector of the input field if any in order to find an element",
          "value": "value to be inserted/filled out if any is needed"
        }
      ]
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
