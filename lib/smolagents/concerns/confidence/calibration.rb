module Smolagents
  module Concerns
    module Confidence
      # Base module for confidence calibration with extensible scorer registry.
      #
      # Provides a unified interface for scoring tool calls and blending
      # confidence signals from multiple sources. Scorers can be registered
      # and selected by name for different use cases.
      #
      # @example Including calibration in a class
      #   class ToolValidator
      #     include Concerns::Confidence::Calibration
      #
      #     def validate(call, tools)
      #       estimate = score_confidence(call, tools)
      #       estimate.high_confidence?
      #     end
      #   end
      #
      # @example Registering a custom scorer
      #   Calibration.register_scorer(:semantic, SemanticScorer)
      #   estimate = validator.score_confidence(call, tools, scorer: :semantic)
      #
      module Calibration
        def self.included(base)
          base.extend ClassMethods
        end

        # Class methods for scorer registration.
        module ClassMethods
          # Registry of scorer implementations.
          def scorers
            @scorers ||= {}
          end

          # Registers a scorer implementation.
          def register_scorer(name, scorer_class) = scorers[name] = scorer_class

          # Returns scorer for given name, falling back to default.
          def scorer_for(name) = scorers[name] || scorers[:default]
        end

        # Scores a tool call using the specified scorer.
        #
        # @param tool_call [Object] The tool call to score
        # @param tools [Hash] Available tools by name
        # @param scorer [Symbol] Scorer name (default: :default)
        # @return [ConfidenceEstimate] Confidence estimate
        def score_confidence(tool_call, tools, scorer: :default)
          scorer_impl = self.class.scorer_for(scorer)
          raise ArgumentError, "Unknown scorer: #{scorer}" unless scorer_impl

          scorer_impl.score(tool_call, tools)
        end

        # Combines multiple confidence signals with optional weights.
        #
        # @param scores [Array<ConfidenceEstimate>] Scores to combine
        # @param weights [Array<Float>, nil] Weights (default: equal)
        # @return [ConfidenceEstimate] Blended estimate
        def blend_confidence(scores, weights: nil)
          return Types::ConfidenceEstimate.syntactic_only(0.0) if scores.empty?

          weights ||= Array.new(scores.size) { 1.0 / scores.size }

          weighted_sum = scores.zip(weights).sum { |s, w| s.blended * w }

          Types::ConfidenceEstimate.new(
            syntactic: scores.sum(&:syntactic) / scores.size,
            semantic: nil,
            blended: weighted_sum.clamp(0.0, 1.0),
            factors: { component_count: scores.size }
          )
        end
      end
    end
  end
end
