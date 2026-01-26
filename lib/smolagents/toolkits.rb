module Smolagents
  # Toolkits - named groups of related tools.
  #
  # Toolkits are automatically recognized by `.tools()` - just use the
  # toolkit name as a symbol and it expands to the tool list.
  #
  # The search toolkit uses the configured search provider. Configure via:
  # - Environment: SMOLAGENTS_SEARCH_PROVIDER=searxng SEARXNG_URL=https://...
  # - Configure block: Smolagents.configure { |c| c.search_provider = :searxng }
  #
  # == Available Toolkits
  #
  # [+:search+]
  #   Web search and information gathering. Uses the configured search_provider
  #   (default: :duckduckgo). Includes Wikipedia search.
  #
  # [+:web+]
  #   Web browsing tools for visiting and extracting content from URLs.
  #
  # [+:data+]
  #   Data processing with Ruby code execution. Best used with code mode.
  #
  # [+:research+]
  #   Full research toolkit combining search and web tools.
  #
  # @example List all available toolkit names
  #   Smolagents::Toolkits.names  #=> [:search, :web, :data, :research]
  #
  # @example Check if a name is a toolkit
  #   Smolagents::Toolkits.toolkit?(:search)  #=> true
  #   Smolagents::Toolkits.toolkit?(:unknown)  #=> false
  #
  # @example Get tools in the web toolkit
  #   Smolagents::Toolkits.web  #=> [:visit_webpage]
  #
  # @example Get tools in the data toolkit
  #   Smolagents::Toolkits.data  #=> [:ruby_interpreter]
  #
  # @example Get a toolkit by name (returns nil for unknown)
  #   Smolagents::Toolkits.get(:web)  #=> [:visit_webpage]
  #   Smolagents::Toolkits.get(:unknown)  #=> nil
  #
  # @example Using toolkits with agents (usage pattern, requires model)
  #   # Toolkits auto-expand when passed to .tools()
  #   # agent = Smolagents.agent
  #   #   .tools(:search, :web)     # Combines search + web tools
  #   #   .model { my_model }
  #   #   .build
  #
  # @see Personas Behavioral instruction templates
  # @see Specializations Pre-built toolkit + persona combinations
  # @see Builders::AgentBuilder#tools Using toolkits in agent builder
  module Toolkits
    class << self
      # Returns tools for web search and information gathering.
      #
      # Uses the configured search_provider (default: :duckduckgo).
      # Always includes Wikipedia search alongside the primary search tool.
      #
      # @return [Array<Symbol>] Tool names for search operations
      #
      # @example Default search tools (DuckDuckGo)
      #   Smolagents::Toolkits.search.include?(:wikipedia_search)  #=> true
      def search
        provider = Smolagents.configuration.search_provider
        tool = Config::SEARCH_PROVIDER_TOOLS[provider] || :duckduckgo_search
        [tool, :wikipedia_search]
      end

      # Returns tools for web browsing and page visiting.
      #
      # @return [Array<Symbol>] Tool names for web operations
      #
      # @example Web toolkit tools
      #   Smolagents::Toolkits.web  #=> [:visit_webpage]
      def web = %i[visit_webpage]

      # Returns tools for data processing with Ruby code.
      #
      # Best used with code mode enabled for the agent.
      #
      # @return [Array<Symbol>] Tool names for data operations
      #
      # @example Data toolkit tools
      #   Smolagents::Toolkits.data  #=> [:ruby_interpreter]
      def data = %i[ruby_interpreter]

      # Returns the full research toolkit (search + web combined).
      #
      # @return [Array<Symbol>] Combined tool names from search and web toolkits
      #
      # @example Research toolkit includes visit_webpage
      #   Smolagents::Toolkits.research.include?(:visit_webpage)  #=> true
      def research = [*search, *web]

      # Returns all available toolkit names.
      #
      # @return [Array<Symbol>] Names of all registered toolkits
      #
      # @example Available toolkits
      #   Smolagents::Toolkits.names  #=> [:search, :web, :data, :research]
      def names = %i[search web data research]

      # Looks up a toolkit by name.
      #
      # @param name [Symbol, String] Toolkit name to look up
      # @return [Array<Symbol>, nil] Tool names, or nil if not a valid toolkit
      #
      # @example Valid toolkit lookup
      #   Smolagents::Toolkits.get(:web)  #=> [:visit_webpage]
      #
      # @example Invalid toolkit returns nil
      #   Smolagents::Toolkits.get(:invalid)  #=> nil
      def get(name)
        return unless names.include?(name.to_sym)

        public_send(name)
      end

      # Checks if a name corresponds to a registered toolkit.
      #
      # @param name [Symbol, String] Name to check
      # @return [Boolean] True if name is a valid toolkit
      #
      # @example Check valid toolkit
      #   Smolagents::Toolkits.toolkit?(:search)  #=> true
      #
      # @example Check invalid name
      #   Smolagents::Toolkits.toolkit?(:invalid)  #=> false
      def toolkit?(name) = names.include?(name.to_sym)
    end
  end
end
