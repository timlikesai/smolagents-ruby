module Smolagents
  module Types
    # Null Object pattern for step parsing failures.
    #
    # NullStep provides a safe default when parsing returns nil or empty.
    # It implements the full step interface with safe defaults, enabling
    # code to handle it uniformly without nil checks.
    #
    # @example Handle parse failures gracefully
    #   step = parse_step(response) || NullStep.empty
    #   step.tool_calls.each { |tc| execute(tc) }  # safely iterates empty array
    #
    # @example Pattern matching with null steps
    #   case step
    #   in NullStep[reason:]
    #     log_parse_failure(reason)
    #   in ActionStep[tool_calls:] if tool_calls.any?
    #     execute_tools(tool_calls)
    #   end
    #
    # @see ActionStep The primary step type this substitutes for
    # @see Types::Steps Step type documentation
    NullStep = Data.define(:reason, :step_number) do
      # Creates a NullStep for empty/nil responses.
      #
      # @return [NullStep] Null step indicating empty response
      def self.empty = new(reason: "empty response", step_number: -1)

      # Creates a NullStep for parse errors.
      #
      # @param message [String] Error description
      # @param step_number [Integer] The step number where parsing failed
      # @return [NullStep] Null step with error details
      def self.parse_error(message, step_number: -1) = new(reason: message, step_number:)

      # Creates a NullStep for nil model output.
      #
      # @param step_number [Integer] The step number with nil output
      # @return [NullStep] Null step indicating nil output
      def self.nil_output(step_number: -1) = new(reason: "nil model output", step_number:)

      # Default initializer with optional step number.
      #
      # @param reason [String] Why this null step was created
      # @param step_number [Integer] Step number (-1 for unknown)
      def initialize(reason:, step_number: -1) = super

      # @return [Boolean] Always true for null steps
      def null? = true

      # @return [Boolean] Always false for null steps
      def final_answer? = false

      # Legacy alias for final_answer? (deprecated - use final_answer? instead)
      # @return [Boolean] Always false for null steps
      alias_method :is_final_answer, :final_answer?

      # @return [Array] Empty tool calls array
      def tool_calls = []

      # @return [Boolean] Always false
      def tool_calls? = false

      # @return [String] Empty string
      def model_output = ""

      # @return [nil] No model output message
      def model_output_message = nil

      # @return [String] Empty string
      def observations = ""

      # @return [nil] No observations images
      def observations_images = nil

      # @return [nil] No action output
      def action_output = nil

      # @return [nil] No error
      def error = nil

      # @return [nil] No code action
      def code_action = nil

      # @return [nil] No timing data
      def timing = nil

      # @return [nil] No token usage
      def token_usage = nil

      # @return [nil] No trace id
      def trace_id = nil

      # @return [nil] No parent trace id
      def parent_trace_id = nil

      # @return [nil] No reasoning content
      def reasoning_content = nil

      # @return [Boolean] Always false
      def reasoning? = false

      # @return [String] Empty evaluation observation
      def evaluation_observation = ""

      # Converts to messages for LLM context.
      # Returns empty array as null steps contribute nothing.
      #
      # @param _opts [Hash] Options (ignored)
      # @return [Array] Empty array
      def to_messages(**_opts) = []

      # Converts to hash for serialization.
      #
      # @return [Hash] Hash with null indicator and reason
      def to_h = { null: true, reason:, step_number: }

      # Pattern matching support.
      #
      # @param _keys [Array, nil] Keys to extract
      # @return [Hash] Fields for pattern matching
      def deconstruct_keys(_keys) = { reason:, step_number:, null: true }
    end
  end
end
