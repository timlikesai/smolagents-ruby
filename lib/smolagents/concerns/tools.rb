require_relative "tools/schema"
require_relative "tools/browser"
require_relative "tools/mcp"

module Smolagents
  module Concerns
    # Tool behavior concerns for building custom tools.
    #
    # This module re-exports tool-specific concerns for easy access.
    # Each concern can be included independently or composed together.
    #
    # @!group Concern Dependency Graph
    #
    # == Dependency Matrix
    #
    #   | Concern    | Depends On              | Depended By | Auto-Includes      |
    #   |------------|-------------------------|-------------|--------------------|
    #   | ToolSchema | -                       | Tool        | -                  |
    #   | Browser    | selenium-webdriver,     | BrowserTool | Html (via Parsing) |
    #   |            | Support::BrowserMode    |             |                    |
    #   | Mcp        | -                       | McpTool     | -                  |
    #
    # == Sub-concern Methods
    #
    #   ToolSchema
    #       +-- to_openai_schema - Convert tool to OpenAI function format
    #       +-- to_anthropic_schema - Convert tool to Anthropic format
    #       +-- to_json_schema - Convert inputs to JSON Schema
    #       +-- validate_inputs!(args) - Validate arguments against schema
    #
    #   Browser
    #       +-- with_browser(&block) - Execute block with Selenium driver
    #       +-- navigate_to(url) - Navigate browser to URL
    #       +-- current_page_content - Get rendered page HTML
    #       +-- take_screenshot(path:) - Capture screenshot
    #       +-- close_browser - Clean up browser session
    #
    #   Mcp (Model Context Protocol)
    #       +-- mcp_tool_definition - Get MCP-compatible tool definition
    #       +-- execute_mcp_call(params) - Execute via MCP protocol
    #
    # == Instance Variables Set
    #
    # *Browser*:
    # - @driver [Selenium::WebDriver] - Active browser driver
    # - @browser_options [Hash] - Browser configuration
    # - @headless [Boolean] - Whether running headless
    #
    # == External Gem Dependencies
    #
    # *Browser*:
    # - selenium-webdriver (required)
    # - webdrivers (optional, for automatic driver management)
    #
    # == Initialization Order
    #
    # Browser should be included after tool initialization since it
    # may lazily load the Selenium gem via Support::GemLoader.
    #
    # @!endgroup
    #
    # @example Building a browser-based tool
    #   class MyWebTool < Tool
    #     include Concerns::Tools::Browser
    #     include Concerns::Tools::ToolSchema
    #   end
    #
    # @see ToolSchema For schema conversion utilities
    # @see Browser For Selenium WebDriver automation
    # @see Mcp For Model Context Protocol support
    module Tools
    end
  end
end
