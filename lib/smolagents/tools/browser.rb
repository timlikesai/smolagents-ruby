module Smolagents
  module Tools
    # Browser automation tools for web interaction.
    #
    # BrowserTools provides a collection of tools for automating web browsers
    # using Selenium WebDriver. These tools enable agents to navigate pages,
    # click elements, search for text, and interact with web content.
    #
    # All browser tools require an active browser driver (Selenium WebDriver).
    # The driver is accessed via the Concerns::Browser mixin and raises an error
    # if no browser is configured.
    #
    # @example Using browser tools with an agent
    #   agent = CodeAgent.new(
    #     model: model,
    #     tools: Smolagents::Tools::BrowserTools.all
    #   )
    #   agent.run("Navigate to example.com and click the login button")
    #
    # @example Composing browser tools in a workflow
    #   browser_tools = BrowserTools.all
    #   agent = CodeAgent.new(model: model, tools: browser_tools)
    #   # Agent can now use go_to, click_element, search_item_ctrl_f, scroll, etc.
    #
    # @see Concerns::Browser The concern that provides browser driver access
    # @see Tool Base class for all tools
    module BrowserTools
      # Returns all available browser tools as instances.
      #
      # @return [Array<Tool>] Array of browser tool instances
      def self.all
        [GoBack.new, ClosePopups.new, Search.new, Click.new, GoTo.new, Scroll.new]
      end

      # Goes back to the previous page in browser history.
      #
      # Equivalent to clicking the back button in a browser.
      # Does nothing if there is no previous page in history.
      #
      # @example
      #   tool = BrowserTools::GoBack.new
      #   tool.call  # => Returns nil, navigates to previous page
      #
      # @see Tool Base class
      class GoBack < Tool
        include Concerns::Browser

        self.tool_name = "go_back"
        self.description = "Goes back to the previous page in browser history."
        self.inputs = {}
        self.output_type = "null"

        # Navigates back to the previous page in browser history.
        #
        # @return [nil] Always returns nil
        # @raise [StandardError] If no browser driver is available
        def execute
          browser_driver&.navigate&.back
          nil
        end
      end

      # Closes visible modals and popups by pressing the Escape key.
      #
      # Sends an Escape keypress to the active browser element. This works for
      # most modals and popups but may not work for cookie consent banners or
      # other custom overlay elements that don't respond to Escape.
      #
      # @example
      #   tool = BrowserTools::ClosePopups.new
      #   tool.call  # => Returns nil, closes any open modals
      #
      # @see Tool Base class
      class ClosePopups < Tool
        include Concerns::Browser

        self.tool_name = "close_popups"
        self.description = "Closes any visible modal or pop-up by pressing Escape. Does not work on cookie banners."
        self.inputs = {}
        self.output_type = "null"

        # Closes popups by sending Escape key to the browser.
        #
        # @return [nil] Always returns nil
        def execute
          return nil unless browser_driver

          browser_driver.action.send_keys(:escape).perform
          nil
        end
      end

      # Searches for text on the current page using Ctrl+F functionality.
      #
      # Finds all elements containing the specified text and scrolls to bring
      # the nth occurrence into view. Returns a message indicating how many
      # matches were found.
      #
      # @example
      #   tool = BrowserTools::Search.new
      #   result = tool.call(text: "Contact Us", nth_result: 1)
      #   # => "Found 2 matches for 'Contact Us'. Focused on element 1 of 2"
      #
      # @example Finding the second occurrence
      #   result = tool.call(text: "Sign Up", nth_result: 2)
      #
      # @see Tool Base class
      class Search < Tool
        include Concerns::Browser

        self.tool_name = "search_item_ctrl_f"
        self.description = "Searches for text on the current page and scrolls to the nth occurrence."
        self.inputs = {
          text: { type: "string", description: "The text to search for" },
          nth_result: { type: "integer", description: "Which occurrence to jump to (default: 1)", nullable: true }
        }
        self.output_type = "string"

        # Searches for text on the page and focuses on a specific occurrence.
        #
        # @param text [String] The text to search for on the page
        # @param nth_result [Integer, nil] Which match to focus on (1-based, default: 1)
        # @return [String] Message with match count and focused element position
        # @raise [StandardError] If the specified nth_result exceeds the number of matches
        def execute(text:, nth_result: 1)
          require_browser!

          nth_result ||= 1
          escaped = escape_xpath_string(text)
          elements = browser_driver.find_elements(:xpath, "//*[contains(text(), #{escaped})]")

          raise "Match ##{nth_result} not found (only #{elements.size} matches found)" if nth_result > elements.size

          elem = elements[nth_result - 1]
          browser_driver.execute_script("arguments[0].scrollIntoView(true);", elem)

          "Found #{elements.size} matches for '#{text}'. Focused on element #{nth_result} of #{elements.size}"
        end
      end

      # Clicks an element on the page by its visible text.
      #
      # Attempts to find and click an element using its link text first,
      # then falls back to finding by XPath if the element is not a link.
      #
      # @example
      #   tool = BrowserTools::Click.new
      #   tool.call(text: "Log In")    # Clicks the "Log In" button
      #   tool.call(text: "Sign Up")   # Clicks the "Sign Up" link
      #
      # @see Tool Base class
      class Click < Tool
        include Concerns::Browser

        self.tool_name = "click_element"
        self.description = "Clicks an element on the page by its visible text or link text."
        self.inputs = {
          text: { type: "string", description: "The visible text of the element to click" }
        }
        self.output_type = "null"

        # Clicks an element matching the given visible text.
        #
        # First attempts to find a link element by link text, then searches
        # for any element containing the text using XPath.
        #
        # @param text [String] The visible text of the element to click
        # @return [nil] Always returns nil
        # @raise [Selenium::WebDriver::Error::NoSuchElementError] If element not found
        def execute(text:)
          require_browser!

          element = browser_driver.find_element(:link_text, text)
          element.click
          nil
        rescue Selenium::WebDriver::Error::NoSuchElementError
          escaped = escape_xpath_string(text)
          element = browser_driver.find_element(:xpath, "//*[contains(text(), #{escaped})]")
          element.click
          nil
        end
      end

      # Navigates to a URL in the browser.
      #
      # Automatically prepends "https://" to URLs that don't start with
      # "http://" or "https://".
      #
      # @example
      #   tool = BrowserTools::GoTo.new
      #   tool.call(url: "example.com")      # Navigates to https://example.com
      #   tool.call(url: "http://site.com")  # Navigates to http://site.com (unchanged)
      #
      # @see Tool Base class
      class GoTo < Tool
        include Concerns::Browser

        self.tool_name = "go_to"
        self.description = "Navigates to a URL in the browser."
        self.inputs = {
          url: { type: "string", description: "The URL to navigate to" }
        }
        self.output_type = "null"

        # Navigates the browser to the given URL.
        #
        # @param url [String] The URL to navigate to (with or without protocol)
        # @return [nil] Always returns nil
        # @raise [StandardError] If no browser driver is available
        def execute(url:)
          require_browser!

          url = "https://#{url}" unless url.start_with?("http://", "https://")
          browser_driver.navigate.to(url)
          nil
        end
      end

      # Scrolls the page up or down by a specified number of pixels.
      #
      # Positive values scroll down, negative values scroll up.
      #
      # @example
      #   tool = BrowserTools::Scroll.new
      #   tool.call(pixels: 500)   # Scroll down 500 pixels
      #   tool.call(pixels: -200)  # Scroll up 200 pixels
      #
      # @see Tool Base class
      class Scroll < Tool
        include Concerns::Browser

        self.tool_name = "scroll"
        self.description = "Scrolls the page up or down by a number of pixels."
        self.inputs = {
          pixels: { type: "integer", description: "Pixels to scroll (positive = down, negative = up)" }
        }
        self.output_type = "null"

        # Scrolls the page in the vertical direction.
        #
        # @param pixels [Integer] Positive to scroll down, negative to scroll up
        # @return [nil] Always returns nil
        # @raise [StandardError] If no browser driver is available
        def execute(pixels:)
          require_browser!

          browser_driver.execute_script("window.scrollBy(0, #{pixels})")
          nil
        end
      end
    end
  end

  # Re-export BrowserTools at the Smolagents level for backward compatibility.
  # @see Smolagents::Tools::BrowserTools
  BrowserTools = Tools::BrowserTools
end
