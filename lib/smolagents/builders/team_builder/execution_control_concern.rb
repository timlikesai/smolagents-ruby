module Smolagents
  module Builders
    # Execution control DSL for TeamBuilder.
    #
    # Adds methods for defining parallel and sequential execution stages.
    module TeamExecutionControlConcern
      # Add a parallel execution stage.
      #
      # All named agents will run concurrently, with the coordinator
      # waiting for all to complete before proceeding.
      #
      # @param agent_names [Array<Symbol, String>] Names of agents to run in parallel
      # @return [TeamBuilder] New builder with stage added
      #
      # @example Run researchers in parallel
      #   Smolagents.team
      #     .agent(a, as: "broad")
      #     .agent(b, as: "deep")
      #     .parallel(:broad, :deep)
      def parallel(*agent_names)
        check_frozen!
        stage = Types::ExecutionStage.parallel(*agent_names)
        add_execution_stage(stage)
      end

      # Add a sequential execution stage after parallel stages.
      #
      # Agents will run one after another in order, typically used
      # after parallel stages for synthesis or aggregation.
      #
      # @param agent_names [Array<Symbol, String>] Names of agents to run sequentially
      # @return [TeamBuilder] New builder with stage added
      #
      # @example Synthesize after parallel research
      #   Smolagents.team
      #     .agent(broad, as: "broad")
      #     .agent(deep, as: "deep")
      #     .agent(synth, as: "synthesizer")
      #     .parallel(:broad, :deep)
      #     .then(:synthesizer)
      def then(*agent_names)
        check_frozen!
        stage = Types::ExecutionStage.sequential(*agent_names)
        add_execution_stage(stage)
      end

      private

      def add_execution_stage(stage)
        current_stages = configuration[:execution_stages] || []
        with_config(execution_stages: current_stages + [stage])
      end
    end
  end
end
