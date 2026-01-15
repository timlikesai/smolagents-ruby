module Smolagents
  module Types
    # A composable capability bundle for agents.
    #
    # Specializations define tools and instructions that can be mixed
    # into agents via the `.with()` DSL method.
    #
    # @example Creating a specialization
    #   spec = Specialization.create(:researcher,
    #     tools: [:web_search, :visit_webpage],
    #     instructions: "You are a research specialist..."
    #   )
    #
    # @example Specialization requiring code execution
    #   spec = Specialization.create(:data_analyst,
    #     tools: [:ruby_interpreter],
    #     instructions: "You analyze data...",
    #     requires: :code
    #   )
    Specialization = Data.define(:name, :tools, :instructions, :requires) do
      def self.create(name, tools: [], instructions: nil, requires: nil)
        new(
          name: name.to_sym,
          tools: Array(tools).map(&:to_sym),
          instructions: instructions&.freeze,
          requires: requires&.to_sym
        )
      end

      def needs_code? = requires == :code
    end
  end
end
