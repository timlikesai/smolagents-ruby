module Smolagents
  module Concerns
    module Confidence
      # Syntactic confidence scoring based on schema validation.
      #
      # Wraps the existing FunctionGemma ConfidenceScorer to produce
      # ConfidenceEstimate values. Falls back to simple validation
      # when FunctionGemma scorer is not available.
      #
      # @example Direct scoring
      #   estimate = Syntactic.score(tool_call, tools)
      #   estimate.high_confidence?  # => true if tool exists and args valid
      #
      module Syntactic
        class << self
          # Scores a tool call based on syntactic validation.
          #
          # @param tool_call [Object] The tool call to score
          # @param tools [Hash] Available tools by name
          # @return [ConfidenceEstimate] Syntactic confidence estimate
          def score(tool_call, tools)
            if function_gemma_available?
              score_with_function_gemma(tool_call, tools)
            else
              score_fallback(tool_call, tools)
            end
          end

          private

          def function_gemma_available?
            defined?(Models::FunctionGemma::ConfidenceScorer)
          end

          def score_with_function_gemma(tool_call, tools)
            speculative = wrap_as_speculative(tool_call)
            result = Models::FunctionGemma::ConfidenceScorer.score(speculative, tools)

            Types::ConfidenceEstimate.syntactic_only(
              result.confidence,
              factors: extract_factors(result)
            )
          end

          def score_fallback(tool_call, tools)
            tool_name = tool_call.respond_to?(:name) ? tool_call.name : tool_call.to_s
            tool = tools[tool_name]

            score = tool ? 0.7 : 0.3
            Types::ConfidenceEstimate.syntactic_only(
              score,
              factors: { tool_exists: !tool.nil? }
            )
          end

          def wrap_as_speculative(tool_call)
            return tool_call if tool_call.respond_to?(:confidence)

            Types::SpeculativeToolCall.from_function_gemma(tool_call, confidence: 0.5)
          end

          def extract_factors(result)
            {
              tool_exists: result.valid_tool?,
              args_valid: result.args_valid?,
              missing_args: result.missing_args,
              type_mismatches: result.type_mismatches
            }
          end
        end
      end
    end
  end
end
