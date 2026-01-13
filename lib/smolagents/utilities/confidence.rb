module Smolagents
  module Utilities
    # Confidence estimation for agent responses.
    #
    # Analyzes agent outputs to estimate response quality based on multiple factors:
    # - Language patterns (uncertainty hedges, refusals, confident assertions)
    # - Execution metrics (steps taken, errors)
    # - Content quality (entity richness, response length)
    #
    # @example Estimate confidence score
    #   confidence = Confidence.estimate(
    #     agent_output,
    #     steps_taken: 3,
    #     max_steps: 10,
    #     error: nil
    #   )
    #   # => 0.75
    #
    # @example Check confidence level
    #   level = Confidence.level(output, steps_taken: 5, max_steps: 10)
    #   # => :high, :medium, or :low
    #
    # @example Quick threshold check
    #   if Confidence.confident?(output, threshold: 0.6, steps_taken: 3, max_steps: 10)
    #     use_answer(output)
    #   else
    #     retry_with_different_approach
    #   end
    #
    module Confidence
      UNCERTAINTY_PATTERNS = [
        /\b(?:maybe|perhaps|possibly|probably)\b/i,
        /\b(?:not sure|uncertain|unsure)\b/i,
        /\b(?:might|could be|may be)\b/i,
        /\b(?:i think|i believe|i guess)\b/i,
        /\b(?:it seems|appears to be)\b/i
      ].freeze

      REFUSAL_PATTERNS = [
        /\b(?:cannot|can't|couldn't)\b/i,
        /\b(?:don't know|do not know)\b/i,
        /\b(?:no information|not available)\b/i,
        /\b(?:unable to|not able to)\b/i,
        /\b(?:i apologize|sorry)\b/i,
        /\b(?:outside my|beyond my)\b/i
      ].freeze

      CONFIDENCE_PATTERNS = [
        /\b(?:definitely|certainly|absolutely)\b/i,
        /\b(?:the answer is|the result is)\b/i,
        /\b(?:confirmed|verified)\b/i
      ].freeze

      class << self
        def estimate(output, steps_taken:, max_steps:, error: nil)
          text = output.to_s
          confidence = 0.5

          confidence += error_penalty(error)
          confidence += steps_penalty(steps_taken, max_steps)
          confidence += language_adjustment(text)
          confidence += content_adjustment(text)
          confidence += efficiency_bonus(steps_taken)
          confidence += length_adjustment(text.length)

          confidence.clamp(0.0, 1.0)
        end

        def confident?(output, threshold: 0.5, **)
          estimate(output, **) >= threshold
        end

        def level(output, **)
          score = estimate(output, **)

          case score
          when 0.7.. then :high
          when 0.4..0.7 then :medium
          else :low
          end
        end

        private

        def error_penalty(error)
          error ? -0.5 : 0
        end

        def steps_penalty(steps_taken, max_steps)
          steps_taken >= max_steps ? -0.3 : 0
        end

        def language_adjustment(text)
          adjustment = 0
          adjustment -= 0.1 * [UNCERTAINTY_PATTERNS.count { |p| text.match?(p) }, 3].min
          adjustment -= 0.3 if REFUSAL_PATTERNS.any? { |p| text.match?(p) }
          adjustment += 0.15 if CONFIDENCE_PATTERNS.any? { |p| text.match?(p) }
          adjustment
        end

        def content_adjustment(text)
          0.1 * [Comparison.extract_entities(text).size, 3].min
        end

        def efficiency_bonus(steps_taken)
          steps_taken <= 2 ? 0.1 : 0
        end

        def length_adjustment(length)
          return -0.2 if length < 10
          return 0.1 if length > 20 && length < 500

          0
        end
      end
    end
  end
end
