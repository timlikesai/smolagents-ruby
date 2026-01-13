module Smolagents
  module Concerns
    module Browser
      INSTRUCTIONS = <<~TEXT.freeze
        You have access to a web browser. Use the browser_go_to tool to navigate to URLs.
        Use browser_click to click on links and buttons by their visible text.
        Use browser_scroll to scroll the page (positive pixels = down, negative = up).
        Use browser_go_back to return to the previous page.
        Use browser_close_popups to dismiss modal dialogs by pressing Escape.
        Use browser_search to find and scroll to text on the page.

        After each action, you will receive a screenshot of the current page state.
        Look at the screenshot to understand what's on the page before deciding your next action.

        Proceed in several steps rather than trying to solve the task in one shot.
        When you have modals or cookie banners, dismiss them before clicking other elements.
        Never try to login to a page.
      TEXT

      class << self
        attr_accessor :driver

        def start(headless: false, window_size: [1000, 1350])
          require "selenium-webdriver"

          options = Selenium::WebDriver::Chrome::Options.new
          options.add_argument("--force-device-scale-factor=1")
          options.add_argument("--window-size=#{window_size.join(",")}")
          options.add_argument("--disable-pdf-viewer")
          options.add_argument("--window-position=0,0")
          options.add_argument("--headless=new") if headless

          @driver = Selenium::WebDriver.for(:chrome, options: options)
        end

        def stop
          @driver&.quit
          @driver = nil
        end

        def screenshot
          return nil unless @driver

          png_bytes = @driver.screenshot_as(:png)
          AgentImage.new(png_bytes, format: "png")
        end

        def current_url
          @driver&.current_url
        end

        def save_screenshot_callback
          lambda do |step, _agent|
            return unless driver

            # Wait for page to be ready using explicit wait (no arbitrary sleep)
            wait_for_page_ready
            image = screenshot
            step.observations_images = [image] if image

            url_info = "Current url: #{current_url}"
            step.observations = step.observations ? "#{step.observations}\n#{url_info}" : url_info
          end
        end

        # Wait for page to be in a ready state using Selenium explicit wait.
        # Checks document.readyState == 'complete' without blocking sleep.
        # @api private
        def wait_for_page_ready
          return unless driver

          # Use Selenium's built-in wait for page load complete
          # This uses Selenium's internal polling, not Ruby sleep
          wait = Selenium::WebDriver::Wait.new(timeout: 10, interval: 0.1)
          wait.until { driver.execute_script("return document.readyState") == "complete" }
        rescue Selenium::WebDriver::Error::TimeoutError
          # Page didn't reach ready state in time - proceed anyway
          nil
        end

        def escape_xpath_string(str)
          return "'#{str}'" unless str.include?("'")
          return "\"#{str}\"" unless str.include?('"')

          parts = str.split("'")
          "concat(#{parts.map { |part| "'#{part}'" }.join(", \"'\", ")})"
        end
      end

      def browser_driver
        Concerns::Browser.driver
      end

      def require_browser!
        raise "Browser not initialized" unless browser_driver
      end

      def escape_xpath_string(str)
        Concerns::Browser.escape_xpath_string(str)
      end
    end
  end
end
