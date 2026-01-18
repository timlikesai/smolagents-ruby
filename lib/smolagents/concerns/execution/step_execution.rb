module Smolagents
  module Concerns
    # Step execution with automatic timing and error handling
    #
    # Wraps step execution in timing, error handling, and state building.
    # Updates timing automatically and logs errors via the logger.
    #
    # @example Executing a step
    #   step = with_step_timing(step_number: 1) do |builder|
    #     builder.observations = "Found results"
    #     builder.action_output = "Answer"
    #   end
    #   # Returns complete ActionStep with timing
    #
    # @see ActionStepBuilder For step building
    # @see Timing For duration tracking
    module StepExecution
      # Execute a step with timing and error handling
      #
      # Creates an ActionStepBuilder, yields to the block for execution,
      # captures any errors, and builds the final step with timing.
      #
      # @param step_number [Integer] Step number for identification
      # @yield [builder] Yields ActionStepBuilder for step configuration
      # @yieldparam builder [ActionStepBuilder] Builder for setting step attributes
      # @return [ActionStep] Complete step with timing and state
      # @example
      #   step = with_step_timing(step_number: 5) do |builder|
      #     result = tool.call(param: "value")
      #     builder.observations = result
      #   end
      def with_step_timing(step_number: 0)
        builder = ActionStepBuilder.new(step_number:)

        begin
          yield builder
        rescue StandardError => e
          builder.error = "#{e.class}: #{e.message}"
          @logger.error("Step error", error: e.message)
        end

        builder.timing = builder.timing.stop
        builder.build
      end
    end
  end
end
