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
