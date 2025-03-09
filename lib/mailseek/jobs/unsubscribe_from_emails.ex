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

    page_title = Playwright.Page.title(page)

    html = Playwright.Page.evaluate(page, "document.documentElement.outerHTML")

    path = "#{Ecto.UUID.generate()}.png"

    # Sleep to wait out slow pages and possible scraper checks
    Process.sleep(10000)

    Playwright.Page.screenshot(page, %{
      path: path
    })

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
end
