require_relative "reflection_memory/store"
require_relative "reflection_memory/analysis"

module Smolagents
  module Concerns
    # Reflection Memory for learning from failures across attempts.
    #
    # Research shows 91% pass@1 on HumanEval with reflection memory.
    # The key insight: store reflections like "Last time I tried X, it failed because Y"
    # and inject them into future attempts.
    #
    # == Composition
    #
    # Auto-includes these sub-concerns:
    #
    #   ReflectionMemory (this concern)
    #       |
    #       +-- Store: add_reflection(), get_reflections(), clear()
    #       |   - Thread-safe reflection storage
    #       |   - LRU eviction when max_reflections exceeded
    #       |
    #       +-- Analysis: analyze_failure(), extract_insight()
    #           - Analyzes failed attempts to generate reflections
    #           - Extracts actionable insights from errors
    #
    # Reflection content is provided to models via Context::Providers.reflections,
    # which contributes to the orchestrated context at the STRATEGIC layer.
    #
    # == Reflection Lifecycle
    #
    # 1. Agent fails on a task
    # 2. Analysis concern generates reflection from failure
    # 3. Store concern saves reflection (with LRU eviction)
    # 4. On next run, Context::Providers.reflections retrieves relevant reflections
    #
    # @see https://arxiv.org/abs/2303.11366 Reflexion paper
    # @see Context::Providers.reflections For context integration
    #
    # @example Basic usage
    #   agent = Smolagents.agent
    #     .model { m }
    #     .reflect(max_reflections: 5)
    #     .build
    #
    # @see SelfRefine For within-run refinement
    # @see MixedRefinement For cross-model refinement
    module ReflectionMemory
      # Maximum reflections to store (prevents unbounded growth).
      DEFAULT_MAX_REFLECTIONS = 10

      def self.included(base)
        base.attr_reader :reflection_config, :reflection_store
        base.include(Analysis)
      end

      private

      def initialize_reflection_memory(reflection_config: nil)
        @reflection_config = reflection_config || Smolagents::Types::ReflectionConfig.disabled
        @reflection_store = Store.new(max_size: @reflection_config.max_reflections)
      end
    end
  end
end
