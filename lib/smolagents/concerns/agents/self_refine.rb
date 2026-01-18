require_relative "self_refine/loop"
require_relative "self_refine/feedback"
require_relative "self_refine/prompts"

module Smolagents
  module Concerns
    # Self-Refine loop for iterative improvement.
    #
    # Research shows ~20% improvement with Generate -> Feedback -> Refine loops.
    # For small models, use external validation (ExecutionOracle) rather than
    # self-critique, as small models cannot reliably self-correct reasoning.
    #
    # == Composition
    #
    # Auto-includes these sub-concerns:
    #
    #   SelfRefine (this concern)
    #       |
    #       +-- Loop: refine_answer(), run_refinement_loop()
    #       |   - Core refinement loop implementation
    #       |   - Iterates until convergence or max_iterations
    #       |
    #       +-- Feedback: get_feedback(), parse_feedback()
    #       |   - Collects feedback from configured source
    #       |   - Supports :execution, :self, :evaluation sources
    #       |
    #       +-- Prompts: refinement_prompt(), feedback_prompt()
    #           - Prompt templates for refinement requests
    #
    # == Standalone Usage
    #
    # Can be used independently of ReActLoop for answer refinement.
    # Works best when combined with CodeExecution for execution-based feedback.
    #
    # == Feedback Sources
    #
    # - :execution - Use ExecutionOracle (recommended for small models)
    # - :self - Self-critique (only for capable models 7B+)
    # - :evaluation - Use evaluation phase results
    #
    # @see https://arxiv.org/abs/2303.17651 Self-Refine paper
    # @see https://arxiv.org/abs/2310.01798 "LLMs Cannot Self-Correct" (ICLR 2024)
    #
    # @example Basic usage with execution feedback
    #   agent = Smolagents.agent
    #     .model { m }
    #     .refine(max_iterations: 3, feedback: :execution)
    #     .build
    #
    # @example Self-critique for capable models
    #   agent = Smolagents.agent
    #     .model { capable_model }
    #     .refine(max_iterations: 2, feedback: :self)
    #     .build
    #
    # @see MixedRefinement For cross-model refinement
    # @see ReflectionMemory For cross-run learning
    module SelfRefine
      # Feedback sources for refinement.
      # - :execution - Use ExecutionOracle (recommended for small models)
      # - :self - Self-critique (only for capable models)
      # - :evaluation - Use evaluation phase results
      FEEDBACK_SOURCES = %i[execution self evaluation].freeze

      # Default refinement configuration.
      DEFAULT_MAX_ITERATIONS = 3
      DEFAULT_FEEDBACK_SOURCE = :execution

      def self.included(base)
        base.attr_reader :refine_config
        base.include(Loop)
        base.include(Feedback)
        base.include(Prompts)
      end

      private

      def initialize_self_refine(refine_config: nil)
        @refine_config = refine_config || Smolagents::Types::RefineConfig.disabled
      end
    end
  end
end
