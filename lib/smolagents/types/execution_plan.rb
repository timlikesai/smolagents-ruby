module Smolagents
  module Types
    # Represents a complete execution plan with ordered stages.
    #
    # Execution plans define how sub-agents should be orchestrated,
    # with support for parallel and sequential execution patterns.
    #
    # @example Research swarm pattern
    #   plan = ExecutionPlan.create([
    #     ExecutionStage.parallel(:broad, :deep, :academic),
    #     ExecutionStage.sequential(:synthesizer)
    #   ])
    #   plan.stages.size  #=> 2
    ExecutionPlan = Data.define(:stages) do
      # Create an execution plan from stages.
      # @param stages [Array<ExecutionStage>] Ordered list of stages
      # @return [ExecutionPlan]
      def self.create(stages)
        validated = stages.map(&:validate!)
        new(stages: validated.freeze)
      end

      # Generate coordination instructions from the plan.
      # @return [String] Human-readable execution instructions
      def to_instructions
        stage_descriptions = stages.each_with_index.map do |stage, idx|
          agent_list = stage.agents.join(", ")
          mode_desc = stage.parallel? ? "in parallel" : "sequentially"
          "Stage #{idx + 1}: Run #{agent_list} #{mode_desc}"
        end

        <<~INSTRUCTIONS
          Execute the following stages in order:
          #{stage_descriptions.join("\n")}

          For parallel stages, delegate to all agents concurrently and wait for all to complete.
          Aggregate results from each stage before proceeding to the next.
        INSTRUCTIONS
      end

      def parallel_stages = stages.select(&:parallel?)
      def sequential_stages = stages.select(&:sequential?)
      def empty? = stages.empty?
    end
  end
end
