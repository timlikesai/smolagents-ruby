module Smolagents
  module Builders
    # Self-refine configuration DSL methods for AgentBuilder.
    #
    # Research shows ~20% improvement with Generate -> Feedback -> Refine loops.
    # For small models, use external validation (:execution) rather than self-critique.
    #
    # @see https://arxiv.org/abs/2303.17651 Self-Refine paper
    module RefineConcern
      # Configure self-refinement (arXiv:2303.17651).
      #
      # @overload refine
      #   Enable refinement with defaults (3 iterations, execution feedback)
      #   @return [AgentBuilder]
      #
      # @overload refine(max_iterations)
      #   Enable with specific iterations
      #   @param max_iterations [Integer]
      #   @return [AgentBuilder]
      #
      # @overload refine(enabled)
      #   Toggle refinement on/off
      #   @param enabled [Boolean]
      #   @return [AgentBuilder]
      #
      # @overload refine(max_iterations:, feedback:, min_confidence:)
      #   Full configuration with named parameters
      #   @param max_iterations [Integer] Maximum refinement attempts (default: 3)
      #   @param feedback [Symbol] Feedback source (:execution, :self, :evaluation)
      #   @param min_confidence [Float] Minimum confidence threshold (0.0-1.0)
      #   @return [AgentBuilder]
      #
      # @example Enable with defaults
      #   Smolagents.agent.refine
      #
      # @example Enable with custom iterations
      #   Smolagents.agent.refine(5)
      #
      # @example Disable refinement
      #   Smolagents.agent.refine(false)
      #
      # @example Self-critique feedback
      #   Smolagents.agent.refine(feedback: :self)
      def refine(iterations_or_enabled = :_default_, max_iterations: nil, feedback: nil, min_confidence: nil)
        check_frozen!

        config = resolve_refine_config(iterations_or_enabled, max_iterations, feedback, min_confidence)
        with_config(refine_config: config)
      end

      private

      def resolve_refine_config(positional, max_iterations, feedback, min_confidence)
        case positional
        when :_default_, true
          build_refine_config(max_iterations:, feedback:, min_confidence:, enabled: true)
        when Integer
          build_refine_config(max_iterations: positional, feedback:, min_confidence:, enabled: true)
        when false, nil
          Types::RefineConfig.disabled
        else
          invalid_refine_arg!(positional)
        end
      end

      def build_refine_config(max_iterations:, feedback:, min_confidence:, enabled:)
        defaults = Types::RefineConfig.default
        Types::RefineConfig.new(
          max_iterations: max_iterations || defaults.max_iterations,
          feedback_source: feedback || defaults.feedback_source,
          min_confidence: min_confidence || defaults.min_confidence,
          enabled:
        )
      end

      def invalid_refine_arg!(value)
        raise ArgumentError, <<~ERROR.gsub(/\s+/, " ").strip
          Invalid refine argument: #{value.inspect}.
          Use Integer, true/false, or keywords (max_iterations:, feedback:).
        ERROR
      end
    end
  end
end
