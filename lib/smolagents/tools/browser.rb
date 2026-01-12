module Smolagents
  module BrowserTools
    def self.all
      [GoBack.new, ClosePopups.new, Search.new, Click.new, GoTo.new, Scroll.new]
    end

    class GoBack < Tool
      include Concerns::Browser

      self.tool_name = "go_back"
      self.description = "Goes back to the previous page in browser history."
      self.inputs = {}
      self.output_type = "null"

      def forward
        browser_driver&.navigate&.back
        nil
      end
    end

    class ClosePopups < Tool
      include Concerns::Browser

      self.tool_name = "close_popups"
      self.description = "Closes any visible modal or pop-up on the page by pressing Escape. Does not work on cookie consent banners."
      self.inputs = {}
      self.output_type = "null"

      def forward
        return nil unless browser_driver

        browser_driver.action.send_keys(:escape).perform
        nil
      end
    end

    class Search < Tool
      include Concerns::Browser

      self.tool_name = "search_item_ctrl_f"
      self.description = "Searches for text on the current page and scrolls to the nth occurrence."
      self.inputs = {
        text: { type: "string", description: "The text to search for" },
        nth_result: { type: "integer", description: "Which occurrence to jump to (default: 1)", nullable: true }
      }
      self.output_type = "string"

      def forward(text:, nth_result: 1)
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

    class Click < Tool
      include Concerns::Browser

      self.tool_name = "click_element"
      self.description = "Clicks an element on the page by its visible text or link text."
      self.inputs = {
        text: { type: "string", description: "The visible text of the element to click" }
      }
      self.output_type = "null"

      def forward(text:)
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

    class GoTo < Tool
      include Concerns::Browser

      self.tool_name = "go_to"
      self.description = "Navigates to a URL in the browser."
      self.inputs = {
        url: { type: "string", description: "The URL to navigate to" }
      }
      self.output_type = "null"

      def forward(url:)
        require_browser!

        url = "https://#{url}" unless url.start_with?("http://", "https://")
        browser_driver.navigate.to(url)
        nil
      end
    end

    class Scroll < Tool
      include Concerns::Browser

      self.tool_name = "scroll"
      self.description = "Scrolls the page up or down by a number of pixels."
      self.inputs = {
        pixels: { type: "integer", description: "Pixels to scroll (positive = down, negative = up)" }
      }
      self.output_type = "null"

      def forward(pixels:)
        require_browser!

        browser_driver.execute_script("window.scrollBy(0, #{pixels})")
        nil
      end
    end
  end
end
