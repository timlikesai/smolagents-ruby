require_relative "execution/step_execution"
require_relative "execution/code_execution"
require_relative "execution/tool_execution"

module Smolagents
  module Concerns
    # Unified execution concern for agent step/code/tool execution.
    #
    # This concern provides a single include for agents that need
    # step timing, code execution, and tool execution capabilities.
    #
    # @example Agent with full execution support
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
    # @see ToolExecution For tool call execution
    module Execution
      def self.included(base)
        base.include(StepExecution)
      end
    end
  end
end
