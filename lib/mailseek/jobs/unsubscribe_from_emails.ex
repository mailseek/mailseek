defmodule Mailseek.Jobs.UnsubscribeFromEmails do
  use Oban.Worker, queue: :browser, max_attempts: 3

  alias Mailseek.Jobs.AnalyzeUnsubscribePage
  alias Mailseek.Jobs.UploadPageScreenshot
  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "provider" => "gmail",
          "user_id" => user_id,
          "message_id" => message_id,
          "unsubscribe_link" => unsubscribe_link
        }
      }) do
    do_perform(user_id, message_id, unsubscribe_link)
  end

  defp do_perform(user_id, message_id, unsubscribe_link) do
    browser = Playwright.launch(:chromium)

    page =
      browser |> Playwright.Browser.new_page()

    page
    |> Playwright.Page.goto(unsubscribe_link)

    # Sleep to wait out slow pages and possible scraper checks
    Process.sleep(10000)

    page_title =
      case Playwright.Page.title(page) do
        nil ->
          "No title found"

        title when is_binary(title) ->
          title

        {:error, _} ->
          "Title couldnt be retrieved"
      end

    path = "#{Ecto.UUID.generate()}.png"

    Playwright.Page.screenshot(page, %{
      path: path
    })

    html =
      Playwright.Page.evaluate(page, """
        (function() {
          // Clone the document to avoid modifying the original
          const clone = document.documentElement.cloneNode(true);

          // Remove all style elements
          const styles = clone.querySelectorAll('style');
          styles.forEach(style => style.remove());

          // Remove all script elements
          const scripts = clone.querySelectorAll('script');
          scripts.forEach(script => script.remove());

          // Remove all link elements with rel="stylesheet"
          const styleLinks = clone.querySelectorAll('link[rel="stylesheet"]');
          styleLinks.forEach(link => link.remove());

          return clone.outerHTML;
        })()
      """)

    Process.sleep(1000)

    Playwright.Browser.close(browser)

    key = "m_#{message_id}/unsubscribe_page.png"

    UploadPageScreenshot.new(%{
      "path" => path,
      "key" => key,
      "bucket" => "unsubscribe_flows",
      "user_id" => user_id,
      "message_id" => message_id,
      "order" => 0
    })
    |> Oban.insert!()

    AnalyzeUnsubscribePage.new(%{
      "provider" => "gmail",
      "user_id" => user_id,
      "message_id" => message_id,
      "html" => html,
      "page_title" => page_title,
      "url" => unsubscribe_link,
      "order" => 1
    })
    |> Oban.insert!()

    :ok
  end

  @impl Oban.Worker
  def timeout(_job), do: :timer.seconds(60)
end
