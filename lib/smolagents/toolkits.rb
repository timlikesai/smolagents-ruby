module Smolagents
  # Toolkits - named groups of related tools.
  #
  # Toolkits are automatically recognized by `.tools()` - just use the
  # toolkit name as a symbol and it expands to the tool list.
  #
  # @example Using toolkits (automatic expansion)
  #   @model = Smolagents::Testing::MockModel.new
  #   @model.queue_final_answer("done")
  #   agent = Smolagents.agent
  #     .tools(:search)           # expands to search tools
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
  #   Smolagents::Toolkits.search  #=> [:duckduckgo_search, :wikipedia_search]
  #   Smolagents::Toolkits.names   #=> [:search, :web, :data, :research]
  module Toolkits
    class << self
      # Web search and information gathering
      def search = %i[duckduckgo_search wikipedia_search]

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
