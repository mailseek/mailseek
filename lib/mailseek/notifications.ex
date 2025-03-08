defmodule Mailseek.Notifications do
  alias Phoenix.PubSub

  def notify(topic, payload) do
    PubSub.broadcast(Mailseek.PubSub, topic, payload)
  end
end
