module Smolagents
  module Types
    # Outcome for tool execution with tool-specific context.
    #
    # CONTAINS ToolResult data - composition pattern.
    # Currently stores tool metadata directly, may wrap ToolResult in future.
    #
    # @example Pattern matching on tool outcome
    #   case outcome
    #   in ToolExecutionOutcome[state: :success, tool_name: "search", value:]
    #     puts "Search returned: #{value}"
    #   in ToolExecutionOutcome[state: :error, tool_name:, error:]
    #     puts "Tool #{tool_name} failed: #{error.message}"
    #   end
    #
    ToolExecutionOutcome = Data.define(
      :state, :value, :error, :duration, :metadata,
      :tool_name,   # Name of the tool that was executed
      :arguments    # Arguments passed to the tool
    ) do
      # Predicate methods from base ExecutionOutcome
      def success? = state == :success
      def final_answer? = state == :final_answer
      def error? = state == :error
      def max_steps? = state == :max_steps_reached
      def timeout? = state == :timeout
      def completed? = success? || final_answer?
      def failed? = error? || max_steps? || timeout?

      def to_event_payload
        {
          outcome: state,
          duration: duration,
          timestamp: Time.now.utc.iso8601,
          metadata: metadata,
          tool_name: tool_name,
          arguments: arguments
        }.tap do |payload|
          payload[:value] = value if completed?
          payload[:error] = error.class.name if error?
          payload[:error_message] = error.message if error?
        end
      end
    end
  end
end
