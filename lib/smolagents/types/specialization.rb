module Smolagents
  module Types
    # A composable capability bundle for agents.
    #
    # Specializations define tools and instructions that can be mixed
    # into agents via the `.with()` DSL method. They bundle related capabilities
    # together for easy reuse across different agent configurations.
    #
    # @!attribute [r] name
    #   @return [Symbol] Unique identifier for the specialization
    # @!attribute [r] tools
    #   @return [Array<Symbol>] Tool names included in this specialization
    # @!attribute [r] instructions
    #   @return [String, nil] Additional system prompt instructions
    # @!attribute [r] requires
    #   @return [Symbol, nil] Requirement indicator (e.g., :code for code execution)
    #
    # @example Creating a specialization
    #   spec = Smolagents::Types::Specialization.create(:researcher,
    #     tools: [:web_search, :visit_webpage],
    #     instructions: "You are a research specialist..."
    #   )
    #   spec.name   # => :researcher
    #   spec.tools  # => [:web_search, :visit_webpage]
    #
    # @example Specialization requiring code execution
    #   spec = Smolagents::Types::Specialization.create(:data_analyst,
    #     tools: [:ruby_interpreter],
    #     instructions: "You analyze data...",
    #     requires: :code
    #   )
    #   spec.needs_code?  # => true
    #
    # @see Smolagents::Builders::AgentBuilder#with For using specializations
    Specialization = Data.define(:name, :tools, :instructions, :requires) do
      # Creates a new Specialization with normalized values.
      #
      # @param name [Symbol, String] Unique identifier for the specialization
      # @param tools [Array<Symbol, String>] Tool names to include
      # @param instructions [String, nil] Additional system prompt instructions
      # @param requires [Symbol, nil] Requirement indicator (e.g., :code)
      # @return [Specialization] New specialization instance
      # @example
      #   Smolagents::Types::Specialization.create(:helper, tools: [:search]).name
      #   # => :helper
      def self.create(name, tools: [], instructions: nil, requires: nil)
        new(
          name: name.to_sym,
          tools: Array(tools).map(&:to_sym),
          instructions: instructions&.freeze,
          requires: requires&.to_sym
        )
      end

      # Checks if this specialization requires code execution capability.
      #
      # @return [Boolean] True if requires is :code
      # @example
      #   spec = Smolagents::Types::Specialization.create(:coder, requires: :code)
      #   spec.needs_code?  # => true
      def needs_code? = requires == :code
    end
  end
end
