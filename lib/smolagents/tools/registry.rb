require_relative "final_answer"
require_relative "ruby_interpreter"
require_relative "user_input"
require_relative "search_tool"
require_relative "duckduckgo_search"
require_relative "bing_search"
require_relative "brave_search"
require_relative "google_search"
require_relative "wikipedia_search"
require_relative "visit_webpage"
require_relative "speech_to_text"
require_relative "searxng_search"

module Smolagents
  # Registry of built-in tools available for agent use.
  #
  # The Tools module maintains a registry of all standard tools that ship with
  # smolagents-ruby. It provides factory methods for instantiating tools by name
  # and listing available tools. Each tool is lazily instantiated when requested.
  #
  # @example Get a specific tool by name
  #   search = Smolagents::Tools.get("duckduckgo_search")
  #   result = search.call(query: "Ruby programming")
  #
  # @example List all available tool names
  #   Smolagents::Tools.names
  #   # => ["final_answer", "ruby_interpreter", "user_input", "duckduckgo_search", ...]
  #
  # @example Create all tools at once
  #   all_tools = Smolagents::Tools.all
  #   agent = CodeAgent.new(tools: all_tools, model: model)
  #
  # @see Tool Base class for all tools
  # @see ToolCollection For grouping tools from multiple sources
  module Tools
    # Registry mapping tool names to their classes.
    #
    # @return [Hash{String => Class}] Frozen hash of name => tool class mappings
    #
    # @example Access directly
    #   klass = Smolagents::Tools::REGISTRY["duckduckgo_search"]
    #   tool = klass.new
    REGISTRY = {
      "final_answer" => FinalAnswerTool,
      "ruby_interpreter" => RubyInterpreterTool,
      "user_input" => UserInputTool,
      "duckduckgo_search" => DuckDuckGoSearchTool,
      "bing_search" => BingSearchTool,
      "brave_search" => BraveSearchTool,
      "google_search" => GoogleSearchTool,
      "wikipedia_search" => WikipediaSearchTool,
      "searxng_search" => SearxngSearchTool,
      "visit_webpage" => VisitWebpageTool,
      "speech_to_text" => SpeechToTextTool
    }.freeze

    # Retrieves and instantiates a tool by name.
    #
    # The special name "web_search" resolves to the configured search provider
    # (default: duckduckgo). Configure via:
    #   Smolagents.configure { |c| c.search_provider = :brave }
    #
    # @param name [String, Symbol] The tool name to look up
    # @return [Tool, nil] A new instance of the tool, or nil if not found
    #
    # @example Get a search tool
    #   tool = Smolagents::Tools.get("wikipedia_search")
    #   tool.call(query: "Ruby programming language")
    #
    # @example Use web_search (resolves to configured provider)
    #   tool = Smolagents::Tools.get("web_search")
    #   # => DuckDuckGoSearchTool by default
    #
    # @see REGISTRY For the list of available tool names
    def self.get(name)
      return resolve_web_search if name.to_s == "web_search"

      REGISTRY[name.to_s]&.new
    end

    # Resolves web_search to the configured search provider.
    # @return [Tool] The configured search tool instance
    # @api private
    def self.resolve_web_search
      provider = Smolagents.configuration.search_provider
      REGISTRY["#{provider}_search"]&.new || DuckDuckGoSearchTool.new
    end

    # Creates new instances of all registered tools.
    #
    # @return [Array<Tool>] Array of newly instantiated tools
    #
    # @example Get all tools for an agent
    #   tools = Smolagents::Tools.all
    #   agent = CodeAgent.new(tools: tools, model: model)
    #
    # @note Each call creates new instances; tools are not cached.
    def self.all = REGISTRY.values.map(&:new)

    # Returns all registered tool names, including the virtual web_search alias.
    #
    # @return [Array<String>] List of available tool names
    #
    # @example List available tools
    #   puts Smolagents::Tools.names.join(", ")
    #   # => "final_answer, ruby_interpreter, web_search, ..."
    def self.names = (REGISTRY.keys + ["web_search"]).uniq
  end

  # Alias for backward compatibility.
  # @see Tools
  DefaultTools = Tools
end
