module Smolagents
  module Concerns
    # Browser automation for web interaction and screenshot capture.
    #
    # Manages Selenium WebDriver instance with integrated:
    # - Screenshot capture for visual feedback
    # - Page ready detection
    # - XPath escaping for safe element selection
    # - URL tracking
    #
    # Provides instructions for agents on browser tool usage patterns.
    #
    # @example Starting the browser
    #   Browser.start(headless: true)
    #   image = Browser.screenshot
    #   Browser.stop
    #
    # @example Using in a tool
    #   class MyBrowserTool < Tool
    #     include Concerns::Browser
    #
    #     def execute(url:)
    #       driver = browser_driver
    #       driver.navigate.to(url)
    #       Browser.wait_for_page_ready
    #       Browser.screenshot
    #     end
    #   end
    #
    # @see Selenium::WebDriver For WebDriver documentation
    module Browser
      # Instructions for agents on how to use browser tools
      #
      # Describes available browser_* tools and interaction patterns.
      # Should be included in agent system prompts when browser tools are available.
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

      # Class methods for browser lifecycle and operations
      class << self
        # The Selenium WebDriver instance
        # @return [Selenium::WebDriver, nil] The driver or nil if not started
        attr_accessor :driver

        # Start a Selenium WebDriver instance for Chrome
        #
        # @param headless [Boolean] Run browser in headless mode (default: false)
        # @param window_size [Array<Integer>] Window size as [width, height] (default: [1000, 1350])
        # @return [Selenium::WebDriver] The created driver
        # @raise [LoadError] If selenium-webdriver gem not installed
        # @example
        #   Browser.start(headless: true)
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

        # Close the WebDriver instance
        #
        # Gracefully quits the driver and clears the reference.
        # Safe to call even if driver not started.
        #
        # @return [nil]
        def stop
          @driver&.quit
          @driver = nil
        end

        # Capture a screenshot of the current page
        #
        # @return [AgentImage, nil] PNG image wrapped in AgentImage, or nil if driver not started
        # @see AgentImage For image manipulation methods
        def screenshot
          return nil unless @driver

          png_bytes = @driver.screenshot_as(:png)
          AgentImage.new(png_bytes, format: "png")
        end

        # Get the current page URL
        #
        # @return [String, nil] Current URL or nil if driver not started
        def current_url
          @driver&.current_url
        end

        # Create a callback for step observations with screenshots
        #
        # Returns a lambda that can be used with agent step callbacks
        # to automatically capture screenshots and URL tracking.
        #
        # @return [Proc] Callback that updates step with screenshot and URL
        # @example Using with agent
        #   agent.on_step(&Browser.save_screenshot_callback)
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
        #
        # Checks document.readyState == 'complete' without blocking sleep.
        # Uses Selenium's internal polling mechanism.
        #
        # @param timeout [Integer] Maximum seconds to wait (default: 10)
        # @return [nil]
        # @raise [Selenium::WebDriver::Error::TimeoutError] If timeout exceeded (caught and ignored)
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

        # Escape a string for safe use in XPath expressions
        #
        # Handles strings with both single and double quotes by using
        # XPath's concat() function to properly escape them.
        #
        # @param str [String] String to escape for XPath
        # @return [String] Escaped string safe for XPath predicates
        # @example
        #   escape_xpath_string("O'Brien")
        #   # => concat('O', \"'\", 'Brien')
        def escape_xpath_string(str)
          return "'#{str}'" unless str.include?("'")
          return "\"#{str}\"" unless str.include?('"')

          parts = str.split("'")
          "concat(#{parts.map { |part| "'#{part}'" }.join(", \"'\", ")})"
        end
      end

      # Get the WebDriver instance
      #
      # @return [Selenium::WebDriver, nil] The driver or nil if not started
      # @raise [StandardError] If browser not initialized (when used with require_browser!)
      def browser_driver
        Concerns::Browser.driver
      end

      # Ensure the browser is initialized
      #
      # @raise [RuntimeError] If browser not initialized
      # @return [void]
      def require_browser!
        raise "Browser not initialized" unless browser_driver
      end

      # Escape a string for safe XPath use
      #
      # Delegates to class method for XPath escaping.
      #
      # @param str [String] String to escape
      # @return [String] Escaped string
      # @see Browser.escape_xpath_string For escaping logic
      def escape_xpath_string(str)
        Concerns::Browser.escape_xpath_string(str)
      end
    end
  end
end
