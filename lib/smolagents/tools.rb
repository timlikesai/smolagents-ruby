require_relative "tools/tool"
require_relative "tools/tool_dsl"
require_relative "tools/result"
require_relative "tools/inline_tool"
require_relative "tools/spawn_agent"
require_relative "tools/registry"
require_relative "tools/managed_agent"
require_relative "tools/mcp_tool"
require_relative "tools/browser"

module Smolagents
  # Namespace for all tool-related classes in Smolagents.
  #
  # The Tools module provides the core building blocks for agent capabilities:
  #
  # ## Core Classes
  #
  # - {Tool} - Base class for all tools; subclass and implement `execute`
  # - {ToolResult} - Chainable, Enumerable wrapper for tool outputs
  #
  # ## Built-in Tools
  #
  # ### Search Tools
  # - {SearchTool} - Base class with DSL for search tools
  # - {DuckDuckGoSearchTool} - Web search (no API key required)
  # - {BingSearchTool} - Bing RSS search (no API key required)
  # - {BraveSearchTool} - Brave Search API
  # - {GoogleSearchTool} - Google Programmable Search Engine
  # - {SearxngSearchTool} - Self-hosted SearXNG metasearch
  # - {WikipediaSearchTool} - Wikipedia article search
  #
  # ### Web Tools
  # - {VisitWebpageTool} - Fetch and convert web pages to markdown
  #
  # ### Utility Tools
  # - {FinalAnswerTool} - Signal task completion
  # - {RubyInterpreterTool} - Execute Ruby code in sandbox
  # - {UserInputTool} - Request input from user
  # - {SpeechToTextTool} - Audio transcription (OpenAI/AssemblyAI)
  #
  # ### Integration Tools
  # - {ManagedAgentTool} - Wrap an agent as a tool for delegation
  # - {MCPTool} - Model Context Protocol tool adapter
  # - {BrowserTools} - Selenium-based browser automation
  #
  # @example Creating a custom tool
  #   class WeatherTool < Smolagents::Tools::Tool
  #     self.tool_name = "weather"
  #     self.description = "Get current weather for a location"
  #     self.inputs = { location: { type: "string", description: "City name" } }
  #     self.output_type = "string"
  #
  #     def execute(location:)
  #       # Fetch weather data...
  #       "Sunny, 72F in #{location}"
  #     end
  #   end
  #
  # @example Using the DSL to define a tool
  #   tool = Smolagents::Tools.define_tool(
  #     "upcase",
  #     description: "Convert text to uppercase",
  #     inputs: { text: { type: "string", description: "Text to convert" } },
  #     output_type: "string"
  #   ) { |text:| text.upcase }
  #
  # @example Using the registry
  #   Smolagents::Tools.get("final_answer").class.ancestors.include?(Smolagents::Tools::Tool)  #=> true
  #
  # @example Working with tool results
  #   result = Smolagents::Tools::ToolResult.new([{title: "Ruby", url: "https://ruby-lang.org"}], tool_name: "search")
  #   result.data.first[:title]  #=> "Ruby"
  #   result.pluck(:title)       #=> ["Ruby"]
  #
  # @note All tool classes are also available at the Smolagents level for
  #   backward compatibility (e.g., `Smolagents::Tool` and `Smolagents::Tools::Tool`
  #   refer to the same class).
  #
  # @see Tool Base class documentation
  # @see ToolResult Result handling documentation
  module Tools
  end
end
