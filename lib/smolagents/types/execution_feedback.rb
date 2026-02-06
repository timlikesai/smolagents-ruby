module Smolagents
  module Types
    # Error categories for execution result classification.
    #
    # Used by ExecutionFeedback to categorize errors for appropriate handling:
    # - :success - No error, execution completed successfully
    # - :syntax_error - Ruby syntax error in generated code
    # - :name_error - Undefined variable/constant reference
    # - :type_error - Type mismatch in operation
    # - :argument_error - Wrong number/type of arguments
    # - :no_method_error - Method called on wrong receiver
    # - :tool_error - Tool invocation failed
    # - :timeout - Execution exceeded time limit
    # - :memory_limit - Memory allocation exceeded
    # - :operation_limit - Operation count exceeded
    # - :runtime_error - Other runtime errors
    EXECUTION_ERROR_CATEGORIES = %i[
      success syntax_error name_error type_error argument_error
      no_method_error tool_error timeout memory_limit operation_limit runtime_error
    ].freeze

    # Structured feedback from execution analysis.
    #
    # Provides actionable information about code execution results, including
    # error classification, location tracking, and fix suggestions. Used by
    # the ExecutionOracle concern for execution-based validation feedback.
    #
    # @example Pattern matching on feedback
    #   case analyze_execution(result)
    #   in ExecutionFeedback[category: :success]
    #     continue_execution
    #   in ExecutionFeedback[category: :syntax_error, suggestion:]
    #     inject_feedback("Fix syntax: #{suggestion}")
    #   in ExecutionFeedback[category:, needs_new_approach?: true]
    #     inject_feedback("Try a different approach: #{category}")
    #   end
    #
    # @see Concerns::ExecutionOracle The oracle concern
    # @see https://arxiv.org/abs/2310.01798 "Large Language Models Cannot Self-Correct"
    ExecutionFeedback = Data.define(
      :category, :message, :suggestion, :location, :details, :confidence
    ) do
      include TypeSupport::Deconstructable

      # Whether execution succeeded.
      # @return [Boolean]
      def success? = category == :success

      # Whether execution failed.
      # @return [Boolean]
      def failure? = !success?

      # Whether this failure has actionable guidance.
      # @return [Boolean]
      def actionable? = failure? && !suggestion.nil? && !suggestion.empty?

      # Whether this is a syntax error that can be fixed in place.
      # @return [Boolean]
      def syntax_fixable? = category == :syntax_error

      # Whether this error requires a fundamentally different approach.
      # Resource limits and tool errors can't be fixed by code changes.
      # @return [Boolean]
      def needs_new_approach?
        %i[tool_error timeout memory_limit operation_limit].include?(category)
      end

      # Formats feedback as an observation string for the agent.
      # @return [String]
      def to_observation
        return "Execution successful." if success?

        parts = ["Error [#{category}]: #{message}"]
        parts << "Location: line #{location[:line]}" if location&.dig(:line)
        parts << "Fix: #{suggestion}" if suggestion
        parts.join("\n")
      end

      class << self
        # Creates a success feedback.
        #
        # @param output [Object] The execution output
        # @return [ExecutionFeedback]
        def success(output: nil)
          new(
            category: :success,
            message: output.to_s,
            suggestion: nil,
            location: nil,
            details: { output: },
            confidence: 1.0
          )
        end

        # Creates a failure feedback with structured error information.
        #
        # @param category [Symbol] Error category (see EXECUTION_ERROR_CATEGORIES)
        # @param message [String] Human-readable error message
        # @param suggestion [String, nil] Suggested fix
        # @param location [Hash, nil] Error location ({ line:, column: })
        # @param details [Hash] Additional error details
        # @param confidence [Float] Confidence in the classification (0.0-1.0)
        # @return [ExecutionFeedback]
        def failure(category:, message:, suggestion:, location: nil, details: {}, confidence: 0.7)
          new(category:, message:, suggestion:, location:, details:, confidence:)
        end

        # Creates a syntax error feedback.
        #
        # @param message [String] Error message
        # @param suggestion [String] Fix suggestion
        # @param location [Hash, nil] Error location
        # @return [ExecutionFeedback]
        def syntax_error(message:, suggestion:, location: nil)
          failure(
            category: :syntax_error,
            message:,
            suggestion:,
            location:,
            confidence: 0.9
          )
        end

        # Creates a timeout feedback.
        #
        # @param message [String] Timeout message
        # @return [ExecutionFeedback]
        def timeout(message: "Execution timed out")
          failure(
            category: :timeout,
            message:,
            suggestion: "Try a simpler approach or break the task into smaller steps",
            confidence: 1.0
          )
        end
      end
    end
  end
end
