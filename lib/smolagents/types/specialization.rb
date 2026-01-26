module Smolagents
  module Types
    # A composable capability bundle for agents.
    #
    # Specializations define tools and instructions that can be mixed
    # into agents via the `.with()` DSL method. They bundle related capabilities
    # together for easy reuse across different agent configurations.
    #
    # All agents think in Ruby code - specializations just add tools and personas.
    #
    # @!attribute [r] name
    #   @return [Symbol] Unique identifier for the specialization
    # @!attribute [r] tools
    #   @return [Array<Symbol>] Tool names included in this specialization
    # @!attribute [r] instructions
    #   @return [String, nil] Additional system prompt instructions
    #
    # @example Creating a specialization
    #   spec = Smolagents::Types::Specialization.create(:researcher,
    #     tools: [:web_search, :visit_webpage],
    #     instructions: "You are a research specialist..."
    #   )
    #   spec.name   # => :researcher
    #   spec.tools  # => [:web_search, :visit_webpage]
    #
    # @see Smolagents::Builders::AgentBuilder#with For using specializations
    Specialization = Data.define(:name, :tools, :instructions) do
      # Creates a new Specialization with normalized values.
      #
      # @param name [Symbol, String] Unique identifier for the specialization
      # @param tools [Array<Symbol, String>] Tool names to include
      # @param instructions [String, nil] Additional system prompt instructions
      # @return [Specialization] New specialization instance
      # @example
      #   Smolagents::Types::Specialization.create(:helper, tools: [:search]).name
      #   # => :helper
      def self.create(name, tools: [], instructions: nil)
        new(
          name: name.to_sym,
          tools: Array(tools).map(&:to_sym),
          instructions: instructions&.freeze
        )
      end
    end
  end
end
