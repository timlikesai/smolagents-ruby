module Smolagents
  module Utilities
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

          confidence -= 0.5 if error

          confidence -= 0.3 if steps_taken >= max_steps

          uncertainty_count = UNCERTAINTY_PATTERNS.count { |p| text.match?(p) }
          confidence -= 0.1 * [uncertainty_count, 3].min

          confidence -= 0.3 if REFUSAL_PATTERNS.any? { |p| text.match?(p) }

          confidence += 0.15 if CONFIDENCE_PATTERNS.any? { |p| text.match?(p) }

          entity_count = Comparison.extract_entities(text).size
          confidence += 0.1 * [entity_count, 3].min

          confidence += 0.1 if steps_taken <= 2

          length = text.length
          confidence += 0.1 if length > 20 && length < 500

          confidence -= 0.2 if length < 10

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
      end
    end
  end
end
