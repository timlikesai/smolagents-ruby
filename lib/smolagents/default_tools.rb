# frozen_string_literal: true

require_relative "default_tools/final_answer_tool"
require_relative "default_tools/ruby_interpreter_tool"
require_relative "default_tools/user_input_tool"
require_relative "default_tools/web_search_tool"
require_relative "default_tools/duckduckgo_search_tool"
require_relative "default_tools/google_search_tool"
require_relative "default_tools/api_web_search_tool"
require_relative "default_tools/visit_webpage_tool"
require_relative "default_tools/wikipedia_search_tool"
require_relative "default_tools/speech_to_text_tool"

module Smolagents
  module DefaultTools
    # Mapping of tool names to tool classes
    TOOL_MAPPING = {
      "final_answer" => FinalAnswerTool,
      "ruby_interpreter" => RubyInterpreterTool,
      "user_input" => UserInputTool,
      "web_search" => WebSearchTool,
      "duckduckgo_search" => DuckDuckGoSearchTool,
      "google_search" => GoogleSearchTool,
      "api_web_search" => ApiWebSearchTool,
      "visit_webpage" => VisitWebpageTool,
      "wikipedia_search" => WikipediaSearchTool,
      "transcriber" => SpeechToTextTool
    }.freeze

    # Get a default tool by name.
    # @param name [String, Symbol] tool name
    # @return [Tool, nil] tool instance, or nil if not found
    def self.get(name)
      tool_class = TOOL_MAPPING[name.to_s]
      tool_class&.new
    end

    # Get all default tools.
    # @return [Array<Tool>] array of tool instances
    def self.all
      TOOL_MAPPING.values.map(&:new)
    end

    # Get available tool names and classes.
    # @return [Hash<String, Class>] mapping of names to tool classes
    def self.available
      TOOL_MAPPING
    end

    # List available tool names.
    # @return [Array<String>] tool names
    def self.names
      TOOL_MAPPING.keys
    end
  end
end
