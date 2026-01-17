module Smolagents
  module Types
    # Immutable result from executing a tool.
    #
    # Wraps the output from tool execution with metadata about success,
    # observations, and whether the tool call produced a final answer.
    # Links back to the original ToolCall via ID.
    #
    # @!attribute [r] id
    #   @return [String] ID linking to original ToolCall
    # @!attribute [r] output
    #   @return [String, nil] Tool execution result
    # @!attribute [r] is_final_answer
    #   @return [Boolean] Whether this is a final answer
    # @!attribute [r] observation
    #   @return [String] Observation about the execution
    # @!attribute [r] tool_call
    #   @return [ToolCall, nil] Original tool call
    #
    # @example Creating tool output from successful call
    #   call = Smolagents::Types::ToolCall.new(name: "search", arguments: {}, id: "1")
    #   output = Smolagents::Types::ToolOutput.from_call(call, output: "Found 10", observation: "OK")
    #   output.output  # => "Found 10"
    #
    # @example Creating tool output for errors
    #   output = Smolagents::Types::ToolOutput.error(id: "1", observation: "Not found")
    #   output.output.nil?  # => true
    #
    # @see ToolCall For the original call
    # @see ActionStep#action_output For step-level output
    ToolOutput = Data.define(:id, :output, :is_final_answer, :observation, :tool_call) do
      # Creates ToolOutput from a successful tool call.
      #
      # @param tool_call [ToolCall] The original tool call
      # @param output [String] The tool's output/result
      # @param observation [String] Observation about the execution
      # @param is_final [Boolean] Whether this is a final answer
      # @return [ToolOutput] Result wrapping the output
      def self.from_call(tool_call, output:, observation:, is_final: false)
        new(id: tool_call.id, output:, is_final_answer: is_final, observation:, tool_call:)
      end

      # Creates ToolOutput representing a tool error.
      #
      # @param id [String] ID linking to original ToolCall
      # @param observation [String] Error message or description
      # @return [ToolOutput] Error result with nil output
      def self.error(id:, observation:)
        new(id:, output: nil, is_final_answer: false, observation:, tool_call: nil)
      end

      # Converts to hash for serialization.
      #
      # @return [Hash] Hash with :id, :output, :is_final_answer, :observation, :tool_call
      def to_h = { id:, output:, is_final_answer:, observation:, tool_call: tool_call&.to_h }

      # Enables pattern matching with `in ToolOutput[output:, is_final_answer:]`.
      #
      # @param keys [Array, nil] Keys to extract (ignored, returns all)
      # @return [Hash] All fields as a hash
      def deconstruct_keys(_keys) = { id:, output:, is_final_answer:, observation:, tool_call: }
    end
  end
end
