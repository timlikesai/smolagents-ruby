require_relative "execution_oracle/error_parser"
require_relative "execution_oracle/suggestion_generator"
require_relative "execution_oracle/confidence_scorer"

module Smolagents
  module Concerns
    # Execution Feedback Oracle for small model validation.
    # Parses execution results and provides structured, actionable feedback.
    # @see https://arxiv.org/abs/2310.01798 "Large Language Models Cannot Self-Correct"
    module ExecutionOracle
      include ExecutionOracle::ErrorParser
      include ExecutionOracle::SuggestionGenerator
      include ExecutionOracle::ConfidenceScorer

      # Error categories for classification.
      # @see Types::EXECUTION_ERROR_CATEGORIES
      ERROR_CATEGORIES = Smolagents::Types::EXECUTION_ERROR_CATEGORIES

      # Alias for brevity within this module.
      # @see Smolagents::Types::ExecutionFeedback
      ExecutionFeedback = Smolagents::Types::ExecutionFeedback

      # Analyzes execution result and returns structured feedback.
      # @param result [ExecutionResult] The execution result to analyze
      # @param code [String, nil] The code that was executed
      # @return [ExecutionFeedback] Structured feedback
      def analyze_execution(result, code = nil)
        return ExecutionFeedback.success(output: result.output) if result.success?

        build_failure_feedback(result.error.to_s, code)
      end

      def build_failure_feedback(error_message, code)
        category = classify_error(error_message)
        details = parse_error_details(category, error_message)
        ExecutionFeedback.failure(
          category:, message: error_message, suggestion: generate_suggestion(category, details, code),
          location: extract_location(error_message, code), details:, confidence: calculate_confidence(category, details)
        )
      end

      # Classifies an error message into a category.
      # @param message [String] Error message
      # @return [Symbol] Error category
      # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity -- pattern matching over many error types
      def classify_error(message)
        return :syntax_error if message.include?("syntax error")
        return :name_error if message&.match?(ErrorParser::ERROR_PATTERNS[:name_error])
        return :no_method_error if message&.match?(ErrorParser::ERROR_PATTERNS[:no_method_error])
        return :type_error if message&.match?(ErrorParser::ERROR_PATTERNS[:type_error])
        return :argument_error if message&.match?(ErrorParser::ERROR_PATTERNS[:argument_error])
        return :tool_error if message&.match?(ErrorParser::ERROR_PATTERNS[:tool_not_found])
        return :timeout if message&.match?(ErrorParser::ERROR_PATTERNS[:timeout])
        return :memory_limit if message&.match?(ErrorParser::ERROR_PATTERNS[:memory_limit])
        return :operation_limit if message&.match?(ErrorParser::ERROR_PATTERNS[:operation_limit])

        :runtime_error
      end
      # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    end
  end
end
