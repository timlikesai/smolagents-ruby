module Smolagents
  module Types
    # Represents a single stage in an execution plan.
    #
    # Stages can be parallel (all agents run concurrently) or sequential
    # (agents run one after another in order).
    #
    # @example Create parallel stage
    #   stage = ExecutionStage.parallel(:researcher, :analyst)
    #   stage.agents  #=> ["researcher", "analyst"]
    #   stage.parallel?  #=> true
    #
    # @example Create sequential stage
    #   stage = ExecutionStage.sequential(:synthesizer)
    #   stage.sequential?  #=> true
    ExecutionStage = Data.define(:agents, :mode) do
      include TypeSupport::StatePredicates

      MODES = %i[parallel sequential].freeze

      state_predicates :mode, parallel: :parallel, sequential: :sequential

      # Create a parallel execution stage.
      # @param names [Array<Symbol, String>] Agent names to run in parallel
      # @return [ExecutionStage]
      def self.parallel(*names) = new(agents: names.flatten.map(&:to_s).freeze, mode: :parallel)

      # Create a sequential execution stage.
      # @param names [Array<Symbol, String>] Agent names to run sequentially
      # @return [ExecutionStage]
      def self.sequential(*names) = new(agents: names.flatten.map(&:to_s).freeze, mode: :sequential)

      def validate!
        raise ArgumentError, "Stage requires at least one agent" if agents.empty?
        raise ArgumentError, "Invalid mode: #{mode}" unless MODES.include?(mode)

        self
      end
    end
  end
end
