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
  # @example Using toolkits (automatic expansion)
  #   @model = Smolagents::Testing::MockModel.new
  #   @model.queue_final_answer("done")
  #   agent = Smolagents.agent
  #     .tools(:search)           # expands to configured search tools
  #     .model { @model }
  #     .build
  #
  # @example Combining toolkits
  #   @model = Smolagents::Testing::MockModel.new
  #   @model.queue_final_answer("done")
  #   agent = Smolagents.agent
  #     .tools(:search, :web)     # combine toolkits
  #     .model { @model }
  #     .build
  #
  # @example Direct access
  #   Smolagents::Toolkits.search  #=> [:searxng_search, :wikipedia_search] (if configured)
  #   Smolagents::Toolkits.names   #=> [:search, :web, :data, :research]
  module Toolkits
    class << self
      # Web search and information gathering.
      # Uses the configured search_provider (default: :duckduckgo).
      def search
        provider = Smolagents.configuration.search_provider
        tool = Config::SEARCH_PROVIDER_TOOLS[provider] || :duckduckgo_search
        [tool, :wikipedia_search]
      end

      # Web browsing and page visiting
      def web = %i[visit_webpage]

      # Data processing (best with code mode)
      def data = %i[ruby_interpreter]

      # Full research toolkit (search + web)
      def research = [*search, *web]

      # All available toolkit names
      def names = %i[search web data research]

      # Get a toolkit by name, or nil if not a toolkit
      def get(name)
        return unless names.include?(name.to_sym)

        public_send(name)
      end

      # Check if a name is a toolkit
      def toolkit?(name) = names.include?(name.to_sym)
    end
  end
end
