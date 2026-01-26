module Smolagents
  module Builders
    # Self-refine configuration DSL methods for AgentBuilder.
    #
    # Research shows ~20% improvement with Generate -> Feedback -> Refine loops.
    # For small models, use external validation (:execution) rather than self-critique.
    #
    # @see https://arxiv.org/abs/2303.17651 Self-Refine paper
    module RefineConcern
      include Support::FlexibleInput

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
      # @example Enable with defaults (3 iterations, execution feedback)
      #   builder = Smolagents.agent.refine
      #   builder.config[:refine_config].enabled  #=> true
      #   builder.config[:refine_config].max_iterations  #=> 3
      #
      # @example Enable with custom iterations (Integer)
      #   builder = Smolagents.agent.refine(5)
      #   builder.config[:refine_config].max_iterations  #=> 5
      #
      # @example Disable refinement (false)
      #   builder = Smolagents.agent.refine(false)
      #   builder.config[:refine_config].enabled  #=> false
      #
      # @example Self-critique feedback (keyword)
      #   builder = Smolagents.agent.refine(feedback: :self)
      #   builder.config[:refine_config].feedback_source  #=> :self
      #
      # @example Full configuration (multiple keywords)
      #   builder = Smolagents.agent.refine(max_iterations: 2, feedback: :evaluation, min_confidence: 0.9)
      #   builder.config[:refine_config].min_confidence  #=> 0.9
      def refine(value = UNSET, max_iterations: nil, feedback: nil, min_confidence: nil)
        check_frozen!
        with_config(refine_config: build_refine_config(value, max_iterations, feedback, min_confidence))
      end

      private

      def build_refine_config(positional, max_iterations, feedback, min_confidence)
        resolved = resolve_refine_iterations(positional, max_iterations)
        return Types::RefineConfig.disabled if resolved == :disabled

        Types::RefineConfig.new(**refine_params(resolved, feedback, min_confidence))
      end

      def resolve_refine_iterations(positional, explicit)
        defaults = Types::RefineConfig.default
        resolve_value_or_toggle(
          positional, explicit,
          value_type: Integer,
          default: defaults.max_iterations,
          disabled: :disabled,
          name: "refine"
        )
      end

      def refine_params(iterations, feedback, min_confidence)
        defaults = Types::RefineConfig.default
        { max_iterations: iterations, feedback_source: feedback || defaults.feedback_source,
          min_confidence: min_confidence || defaults.min_confidence, enabled: true }
      end
    end
  end
end
