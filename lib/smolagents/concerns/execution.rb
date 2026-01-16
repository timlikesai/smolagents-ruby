require_relative "execution/step_execution"
require_relative "execution/code_execution"

module Smolagents
  module Concerns
    # Unified execution concern for agent step and code execution.
    #
    # All agents write Ruby code. There is one execution paradigm.
    #
    # @example Agent with execution support
    #   class MyAgent
    #     include Concerns::Execution
    #     include Concerns::ReActLoop
    #
    #     def step(task)
    #       with_step_timing(step_number: @step_count) do |builder|
    #         execute_step(builder)
    #       end
    #     end
    #   end
    #
    # @see StepExecution For step timing and error handling
    # @see CodeExecution For code generation and sandboxed execution
    module Execution
      def self.included(base)
        base.include(StepExecution)
      end
    end
  end
end
