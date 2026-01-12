# frozen_string_literal: true

module Smolagents
  module Utilities
    # Heuristic-based confidence estimation for agent outputs.
    #
    # Used for cascade routing decisions, filtering low-confidence answers
    # in ensembles, and knowing when to escalate to stronger models.
    #
    # @example Estimate confidence
    #   Confidence.estimate(result.output, steps_taken: 3, max_steps: 10)
    #   #=> 0.7
    #
    # @example Use for cascade routing
    #   if Confidence.estimate(output, steps_taken:, max_steps:) < 0.5
    #     escalate_to_stronger_model
    #   end
    #
    module Confidence
      # Language patterns indicating uncertainty
      UNCERTAINTY_PATTERNS = [
        /\b(?:maybe|perhaps|possibly|probably)\b/i,
        /\b(?:not sure|uncertain|unsure)\b/i,
        /\b(?:might|could be|may be)\b/i,
        /\b(?:i think|i believe|i guess)\b/i,
        /\b(?:it seems|appears to be)\b/i
      ].freeze

      # Language patterns indicating refusal or inability
      REFUSAL_PATTERNS = [
        /\b(?:cannot|can't|couldn't)\b/i,
        /\b(?:don't know|do not know)\b/i,
        /\b(?:no information|not available)\b/i,
        /\b(?:unable to|not able to)\b/i,
        /\b(?:i apologize|sorry)\b/i,
        /\b(?:outside my|beyond my)\b/i
      ].freeze

      # Language patterns indicating high confidence
      CONFIDENCE_PATTERNS = [
        /\b(?:definitely|certainly|absolutely)\b/i,
        /\b(?:the answer is|the result is)\b/i,
        /\b(?:confirmed|verified)\b/i
      ].freeze

      class << self
        # Estimate confidence in an agent's output.
        #
        # @param output [String, #to_s] The agent's output
        # @param steps_taken [Integer] Number of steps the agent took
        # @param max_steps [Integer] Maximum allowed steps
        # @param error [Exception, nil] Any error that occurred
        # @return [Float] Confidence score 0.0-1.0
        def estimate(output, steps_taken:, max_steps:, error: nil)
          text = output.to_s
          confidence = 0.5 # Base confidence

          # Penalize errors
          confidence -= 0.5 if error

          # Penalize hitting step limit (agent may have given up)
          confidence -= 0.3 if steps_taken >= max_steps

          # Penalize uncertainty language
          uncertainty_count = UNCERTAINTY_PATTERNS.count { |p| text.match?(p) }
          confidence -= 0.1 * [uncertainty_count, 3].min

          # Penalize refusal language
          confidence -= 0.3 if REFUSAL_PATTERNS.any? { |p| text.match?(p) }

          # Reward confidence language
          confidence += 0.15 if CONFIDENCE_PATTERNS.any? { |p| text.match?(p) }

          # Reward specific facts (entities indicate concrete answer)
          entity_count = Comparison.extract_entities(text).size
          confidence += 0.1 * [entity_count, 3].min

          # Reward quick decisions (fewer steps = more decisive)
          confidence += 0.1 if steps_taken <= 2

          # Reward reasonable length (not too short, not rambling)
          length = text.length
          confidence += 0.1 if length > 20 && length < 500

          # Penalize very short responses
          confidence -= 0.2 if length < 10

          confidence.clamp(0.0, 1.0)
        end

        # Check if output meets confidence threshold.
        #
        # @param output [String, #to_s] The agent's output
        # @param threshold [Float] Minimum confidence (default: 0.5)
        # @return [Boolean]
        def confident?(output, threshold: 0.5, **)
          estimate(output, **) >= threshold
        end

        # Categorize confidence into levels.
        #
        # @param output [String, #to_s] The agent's output
        # @return [Symbol] :high, :medium, or :low
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
