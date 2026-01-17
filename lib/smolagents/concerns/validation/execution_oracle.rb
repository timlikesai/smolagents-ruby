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
      ERROR_CATEGORIES = %i[
        success syntax_error name_error type_error argument_error
        no_method_error tool_error timeout memory_limit operation_limit runtime_error
      ].freeze

      # Structured feedback from execution analysis.
      ExecutionFeedback = Data.define(
        :category, :message, :suggestion, :location, :details, :confidence
      ) do
        def success? = category == :success
        def failure? = !success?
        def actionable? = failure? && suggestion && !suggestion.empty?
        def syntax_fixable? = category == :syntax_error

        def needs_new_approach?
          %i[tool_error timeout memory_limit operation_limit].include?(category)
        end

        def to_observation
          return "Execution successful." if success?

          parts = ["Error [#{category}]: #{message}"]
          parts << "Location: line #{location[:line]}" if location&.dig(:line)
          parts << "Fix: #{suggestion}" if suggestion
          parts.join("\n")
        end

        class << self
          def success(output: nil)
            new(
              category: :success, message: output.to_s, suggestion: nil,
              location: nil, details: { output: }, confidence: 1.0
            )
          end

          def failure(category:, message:, suggestion:, location: nil, details: {}, confidence: 0.7)
            new(category:, message:, suggestion:, location:, details:, confidence:)
          end
        end
      end

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
    end
  end
end
