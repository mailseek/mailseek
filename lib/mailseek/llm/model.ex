defmodule Mailseek.LLM.Model do
  alias LangChain.ChatModels.ChatOpenAI
  alias Mailseek.LLM.Model.DeepSeek

  @models [
    openai: [
      "gpt-4o-mini": "gpt-4o-mini",
      "gpt-4o": "gpt-4o"
    ],
    deepseek: [
      "deepseek-chat": "deepseek-chat"
    ]
  ]

  def parse(model = "gpt" <> _rest, %{temperature: temperature} = params) do
    ChatOpenAI.new!(%{
      model: get_model_value!(model),
      temperature: temperature,
      stream: false,
      json_response: Map.get(params, :json_response, false)
    })
  end

  def parse(model = "deepseek" <> _rest, %{temperature: temperature} = params) do
    ChatOpenAI.new!(%{
      model: get_model_value!(model),
      temperature: temperature,
      endpoint: DeepSeek.endpoint(),
      api_key: DeepSeek.api_key(),
      stream: false,
      json_response: Map.get(params, :json_response, false)
    })
  end

  def parse(model, _) do
    raise "Unsupported model: #{model}"
  end

  defp get_model_value!(model) do
    @models
    |> Enum.flat_map(fn {_provider, models} -> models end)
    |> Enum.find(fn {name, _} -> "#{name}" == model end)
    |> case do
      nil -> raise "Unsupported model: #{model}"
      {_name, value} -> value
    end
  end
end
