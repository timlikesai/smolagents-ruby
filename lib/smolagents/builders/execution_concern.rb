module Smolagents
  module Builders
    # Run methods for AgentBuilder.
    module ExecutionConcern
      # Build and run a task in one step.
      # @param task [String] The task to execute
      # @param kwargs [Hash] Options passed to Agent#run
      # @return [Types::RunResult] The execution result
      def run(task, **)
        build.run(task, **)
      end

      # Build and run a task as a Fiber for interactive control.
      # @param task [String] The task to execute
      # @param kwargs [Hash] Options passed to Agent#run_fiber
      # @return [Fiber] A fiber that yields each step
      def run_fiber(task, **)
        build.run_fiber(task, **)
      end
    end
  end
end
