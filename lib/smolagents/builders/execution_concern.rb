module Smolagents
  module Builders
    # Run methods for AgentBuilder.
    #
    # Provides convenience methods to build and run an agent in a single step.
    # These methods create the agent from the builder configuration and then
    # execute the task.
    #
    # @see AgentBuilder#build For building without running
    module ExecutionConcern
      # Build and run a task in one step.
      #
      # Creates the agent from the current builder configuration and runs
      # the specified task. Useful for quick one-off agent executions.
      #
      # @param task [String] The task to execute
      # @param options [Hash] Options passed to Agent#run
      # @return [Types::RunResult] The execution result
      #
      # @example Run directly from builder
      #   result = Smolagents.agent
      #     .model { Smolagents::OpenAIModel.new(model_id: "gpt-4") }
      #     .tools(:search)
      #     .run("Search for Ruby conferences")
      def run(task, **)
        build.run(task, **)
      end

      # Build and run a task as a Fiber for interactive control.
      #
      # Creates the agent and returns a Fiber that yields each step.
      # Useful for streaming results or implementing interactive UIs.
      #
      # @param task [String] The task to execute
      # @param options [Hash] Options passed to Agent#run_fiber
      # @return [Fiber] A fiber that yields each step
      #
      # @example Run with fiber for step-by-step control
      #   fiber = Smolagents.agent
      #     .model { Smolagents::OpenAIModel.new(model_id: "gpt-4") }
      #     .run_fiber("Solve the task")
      def run_fiber(task, **)
        build.run_fiber(task, **)
      end
    end
  end
end
