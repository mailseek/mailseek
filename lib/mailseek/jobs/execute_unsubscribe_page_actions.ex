defmodule Mailseek.Jobs.ExecuteUnsubscribePageActions do
  use Oban.Worker, queue: :browser, max_attempts: 3

  alias Mailseek.Jobs.AnalyzeUnsubscribeResult
  alias Mailseek.Jobs.UploadPageScreenshot
  alias Mailseek.Gmail.Messages

  @impl true
  def perform(%Oban.Job{
        args: %{
          "provider" => "gmail",
          "user_id" => user_id,
          "message_id" => message_id,
          "instruction" => %{} = instruction,
          "url" => url
        }
      }) do
    do_perform(user_id, message_id, instruction, url)
  end

  defp do_perform(
         _user_id,
         message_id,
         %{
           "action_needed" => false
         },
         _url
       ) do
    # No action needed

    message_id
    |> Messages.get_message()
    |> Messages.update_message(%{status: "unsubscribed"})

    :ok
  end

  defp do_perform(
         user_id,
         message_id,
         %{
           "action_needed" => true,
           "actions" => actions
           # "reason" => reason
         },
         url
       ) do
    browser = Playwright.launch(:chromium)

    batch_id = Ecto.UUID.generate()

    page =
      browser |> Playwright.Browser.new_page()

    first_visit_path = "#{batch_id}_first_visit_screenshot.png"

    Playwright.Page.screenshot(page, %{
      path: first_visit_path
    })

    page
    |> Playwright.Page.goto(url)

    # Sleep to wait out slow pages and possible scraper checks
    Process.sleep(10000)

    second_visit_path = "#{batch_id}_second_visit_screenshot.png"

    Playwright.Page.screenshot(page, %{
      path: second_visit_path
    })

    img_paths =
      actions
      |> Enum.with_index()
      |> Enum.map(fn {action, index} ->
        case action do
          %{"action" => "fill_out"} ->
            fill_input(page, action)

          %{"action" => "click"} ->
            click_element(page, action)

          %{"action" => "check"} ->
            check_element(page, action)

          %{"action" => "uncheck"} ->
            check_element(page, action)
        end

        path = "#{batch_id}_after_action_#{index}_screenshot.png"

        Playwright.Page.screenshot(page, %{
          path: path
        })

        path
      end)

    Process.sleep(5000)

    final_img_path = "#{batch_id}_after_actions_screenshot.png"

    Playwright.Page.screenshot(page, %{
      path: final_img_path
    })

    result_html = Playwright.Page.evaluate(page, "document.documentElement.outerHTML")

    Playwright.Browser.close(browser)

    AnalyzeUnsubscribeResult.new(%{
      "provider" => "gmail",
      "user_id" => user_id,
      "message_id" => message_id,
      "html" => result_html,
      "url" => url
    })
    |> Oban.insert!()

    [first_visit_path, second_visit_path]
    |> Enum.concat(img_paths)
    |> Enum.concat([final_img_path])
    |> Enum.with_index()
    |> Enum.each(fn {path, index} ->
      key = "m_#{message_id}/#{path}"

      UploadPageScreenshot.new(%{
        "path" => path,
        "key" => key,
        "bucket" => "unsubscribe_flows",
        "user_id" => user_id,
        "message_id" => message_id,
        "order" => 10 + index
      })
      |> Oban.insert!()
    end)

    :ok
  end

  defp check_element(page, %{
         "action" => action_item,
         "selector" => selector
       })
       when action_item in ["check", "uncheck"] do
    locator =
      Playwright.Page.locator(page, selector)

    Playwright.Locator.check(locator)
  end

  defp click_element(page, %{
         "action" => "click",
         "selector" => selector
       }) do
    Playwright.Page.click(page, selector)
  end

  defp fill_input(page, %{
         "action" => "fill_out",
         "selector" => selector,
         "value" => value
       }) do
    Playwright.Page.fill(page, selector, value)
  end

  @impl Oban.Worker
  def timeout(_job), do: :timer.seconds(120)
end
