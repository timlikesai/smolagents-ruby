module Smolagents
  module Concerns
    module ExecutionOracle
      # Calculates confidence scores for error suggestions.
      #
      # Confidence reflects how actionable the suggestion is.
      # Higher confidence means the suggestion is more likely to fix the issue.
      module ConfidenceScorer
        # Calculates confidence in the generated suggestion.
        # @param category [Symbol] Error category
        # @param details [Hash] Parsed error details
        # @return [Float] Confidence score (0.0-1.0)
        CONFIDENCE_RULES = {
          syntax_error: ->(d) { d.any? ? 0.9 : 0.7 },
          name_error: ->(d) { d[:undefined_name] ? 0.85 : 0.6 },
          no_method_error: ->(d) { d[:undefined_method] ? 0.85 : 0.6 },
          type_error: ->(d) { d[:from_type] && d[:to_type] ? 0.8 : 0.5 },
          argument_error: ->(d) { d[:given] && d[:expected] ? 0.9 : 0.6 },
          tool_error: ->(d) { d[:tool_name] ? 0.95 : 0.7 },
          timeout: ->(_) { 0.8 }, memory_limit: ->(_) { 0.8 }, operation_limit: ->(_) { 0.8 }
        }.freeze

        def calculate_confidence(category, details)
          CONFIDENCE_RULES.fetch(category, ->(_) { 0.5 }).call(details)
        end
      end
    end
  end
end
