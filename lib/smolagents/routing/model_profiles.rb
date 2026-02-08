# frozen_string_literal: true

module Smolagents
  module Routing
    # Pre-configured profiles for known models based on empirical testing.
    #
    # Each profile defines optimal confidence thresholds based on
    # observed accuracy and failure patterns from structured testing.
    #
    # @example Using a profile
    #   profile = ModelProfiles.for("functiongemma-270m-it-mlx")
    #   config = profile.to_config
    #
    module ModelProfiles
      # Model profile with empirically-tuned settings.
      Profile = Data.define(
        :model_pattern,
        :display_name,
        :accuracy,
        :avg_latency_ms,
        :high_threshold,
        :low_threshold,
        :known_weaknesses,
        :notes
      ) do
        def matches?(model_id)
          model_id.match?(model_pattern)
        end

        def to_config
          Types::ToolRouterConfig.new(
            enabled: true,
            model_id: nil, # Set by caller
            high_confidence_threshold: high_threshold,
            low_confidence_threshold: low_threshold,
            max_parallel_calls: 3,
            fallback_on_error: true,
            collect_traces: true
          )
        end

        def recommended? = accuracy >= 0.7
        def fast? = avg_latency_ms < 1000
        def balanced? = recommended? && fast?
      end

      # Profiles based on evaluation results (2026-02-08)
      PROFILES = [
        Profile.new(
          model_pattern: /granite.*micro/i,
          display_name: "Granite 4.0 Micro",
          accuracy: 1.0,
          avg_latency_ms: 2807,
          high_threshold: 0.7,  # Can trust more - very accurate
          low_threshold: 0.4,
          known_weaknesses: [],
          notes: "100% accurate but 5x slower than FunctionGemma"
        ),

        Profile.new(
          model_pattern: /lfm.*1\.2b/i,
          display_name: "LFM 1.2B Instruct",
          accuracy: 0.833,
          avg_latency_ms: 890,
          high_threshold: 0.75,
          low_threshold: 0.45,
          known_weaknesses: [:over_triggers_on_trivial],
          notes: "Best balance of accuracy and speed"
        ),

        Profile.new(
          model_pattern: /functiongemma/i,
          display_name: "FunctionGemma 270M",
          accuracy: 0.667,
          avg_latency_ms: 568,
          high_threshold: 0.85,  # Require higher confidence due to gaps
          low_threshold: 0.55,
          known_weaknesses: [:search_gaps, :over_triggers_on_trivial],
          notes: "Fastest but needs higher thresholds to compensate for gaps"
        ),

        Profile.new(
          model_pattern: /gemma-3n-e2b/i,
          display_name: "Gemma 3N E2B",
          accuracy: 0.667,
          avg_latency_ms: 5876,
          high_threshold: 0.85,
          low_threshold: 0.55,
          known_weaknesses: [:file_operations, :over_triggers_on_trivial],
          notes: "Same accuracy as FunctionGemma but 10x slower - not recommended"
        ),

        Profile.new(
          model_pattern: /gemma-3n-e4b/i,
          display_name: "Gemma 3N E4B",
          accuracy: 0.667,
          avg_latency_ms: 6629,
          high_threshold: 0.85,
          low_threshold: 0.55,
          known_weaknesses: [:file_operations, :over_triggers_on_trivial],
          notes: "Larger but no better than E2B - not recommended for routing"
        ),

        Profile.new(
          model_pattern: /qwen3-0\.6b/i,
          display_name: "Qwen3 0.6B",
          accuracy: 0.5,
          avg_latency_ms: 1327,
          high_threshold: 0.95,  # Very high - mostly delegate
          low_threshold: 0.7,
          known_weaknesses: [:search, :calculation, :file_operations],
          notes: "Too small for reliable tool routing - use for experimentation only"
        ),

        Profile.new(
          model_pattern: /granite.*tiny/i,
          display_name: "Granite Tiny",
          accuracy: 0.167,
          avg_latency_ms: 2862,
          high_threshold: 0.99,  # Effectively always delegate
          low_threshold: 0.95,
          known_weaknesses: [:all],
          notes: "Nearly useless for tool routing - do not use"
        )
      ].freeze

      class << self
        # Returns profile for a model ID.
        #
        # @param model_id [String] Model identifier
        # @return [Profile, nil] Matching profile or nil
        def for(model_id)
          PROFILES.find { |p| p.matches?(model_id) }
        end

        # Returns a config for a model ID with profile-based tuning.
        #
        # @param model_id [String] Model identifier
        # @return [Types::ToolRouterConfig] Tuned configuration
        def config_for(model_id)
          profile = self.for(model_id)
          if profile
            profile.to_config.with(model_id:)
          else
            # Unknown model - use conservative defaults
            Types::ToolRouterConfig.conservative(model_id)
          end
        end

        # Returns recommended models for tool routing.
        #
        # @return [Array<Profile>] Profiles with accuracy >= 70%
        def recommended
          PROFILES.select(&:recommended?)
        end

        # Returns the best balanced model (fast + accurate).
        #
        # @return [Profile, nil] Best balanced profile
        def best_balanced
          PROFILES.select(&:balanced?).max_by(&:accuracy)
        end

        # Returns the fastest recommended model.
        #
        # @return [Profile, nil] Fastest profile with accuracy >= 70%
        def fastest_recommended
          recommended.min_by(&:avg_latency_ms)
        end

        # Returns the most accurate model.
        #
        # @return [Profile, nil] Most accurate profile
        def most_accurate
          PROFILES.max_by(&:accuracy)
        end
      end
    end
  end
end
