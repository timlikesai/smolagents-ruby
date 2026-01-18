module Smolagents
  module Builders
    # Coordinator configuration methods for TeamBuilder.
    #
    # Provides chainable configuration methods for the coordinator agent:
    # instructions, type, max steps, and planning interval.
    module TeamBuilderCoordinatorConfig
      # Set the shared model for the coordinator and sub-agents.
      #
      # The model block is evaluated lazily at build time. Sub-agents that
      # don't have their own model will inherit this one.
      #
      # @yield Block returning a Model instance
      # @return [TeamBuilder] New builder with model configured
      #
      # @example Setting team model
      #   builder = Smolagents.team.model { Smolagents::OpenAIModel.new(model_id: "gpt-4") }
      #   builder.config[:model_block].nil?
      #   #=> false
      def model(&block) = with_config(model_block: block)

      # Set coordination instructions for the coordinator agent.
      #
      # These instructions guide how the coordinator delegates tasks to sub-agents
      # and combines their results.
      #
      # @param instructions [String] How to coordinate sub-agents
      # @return [TeamBuilder] New builder with instructions set
      #
      # @example Setting coordination strategy
      #   builder = Smolagents.team.coordinate("First research the topic, then summarize findings")
      #   builder.config[:coordinator_instructions]
      #   #=> "First research the topic, then summarize findings"
      def coordinate(instructions)
        check_frozen!
        validate!(:coordinate, instructions)
        with_config(coordinator_instructions: instructions)
      end

      # Set the coordinator agent type.
      #
      # @param type [Symbol] Agent type: :code (writes code) or :tool (uses tool calling)
      # @return [TeamBuilder] New builder with coordinator type set
      #
      # @example Setting coordinator type
      #   builder = Smolagents.team.coordinator(:tool)
      #   builder.config[:coordinator_type]
      #   #=> :tool
      def coordinator(type) = with_config(coordinator_type: type.to_sym)

      # Set the maximum steps for the coordinator agent.
      #
      # @param count [Integer] Maximum steps (1-Config::MAX_STEPS_LIMIT)
      # @return [TeamBuilder] New builder with max steps set
      #
      # @example Setting max steps
      #   builder = Smolagents.team.max_steps(25)
      #   builder.config[:max_steps]
      #   #=> 25
      def max_steps(count)
        check_frozen!
        validate!(:max_steps, count)
        with_config(max_steps: count)
      end

      # Configure planning for the coordinator.
      #
      # @param interval [Integer] Steps between re-planning
      # @return [TeamBuilder] New builder with planning configured
      #
      # @example Enabling planning
      #   builder = Smolagents.team.planning(interval: 5)
      #   builder.config[:planning_interval]
      #   #=> 5
      def planning(interval:) = with_config(planning_interval: interval)
    end
  end
end
