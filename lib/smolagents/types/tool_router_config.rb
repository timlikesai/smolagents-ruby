module Smolagents
  module Types
    # Configuration for the ToolRouter dispatcher.
    #
    # Defines how tool routing decisions are made, including which model
    # to use for fast dispatch, confidence thresholds, and fallback behavior.
    #
    # @!attribute [r] enabled
    #   @return [Boolean] Whether fast routing is enabled
    # @!attribute [r] model_id
    #   @return [String, nil] Model ID for fast dispatcher (nil = use primary)
    # @!attribute [r] high_confidence_threshold
    #   @return [Float] Threshold for direct execution (0.0-1.0)
    # @!attribute [r] low_confidence_threshold
    #   @return [Float] Threshold below which to delegate (0.0-1.0)
    # @!attribute [r] max_parallel_calls
    #   @return [Integer] Maximum parallel tool calls to allow
    # @!attribute [r] fallback_on_error
    #   @return [Boolean] Whether to fallback to primary on dispatcher error
    # @!attribute [r] collect_traces
    #   @return [Boolean] Whether to collect traces for training
    #
    # @example Default configuration (disabled)
    #   config = ToolRouterConfig.default
    #   config.enabled?  # => false
    #
    # @example Enable with FunctionGemma
    #   config = ToolRouterConfig.with_model("functiongemma-270m-it-mlx")
    #   config.enabled?  # => true
    #
    ToolRouterConfig = Data.define(
      :enabled,
      :model_id,
      :high_confidence_threshold,
      :low_confidence_threshold,
      :max_parallel_calls,
      :fallback_on_error,
      :collect_traces
    ) do
      # Default configuration (disabled, uses primary model).
      def self.default
        new(
          enabled: false,
          model_id: nil,
          high_confidence_threshold: 0.8,
          low_confidence_threshold: 0.5,
          max_parallel_calls: 3,
          fallback_on_error: true,
          collect_traces: false
        )
      end

      # Configuration with a specific dispatcher model.
      #
      # @param model_id [String] Model ID for the fast dispatcher
      # @param collect_traces [Boolean] Whether to collect training traces
      # @return [ToolRouterConfig]
      def self.with_model(model_id, collect_traces: false)
        new(
          enabled: true,
          model_id:,
          high_confidence_threshold: 0.8,
          low_confidence_threshold: 0.5,
          max_parallel_calls: 3,
          fallback_on_error: true,
          collect_traces:
        )
      end

      # Configuration for FunctionGemma specifically.
      #
      # @param collect_traces [Boolean] Whether to collect training traces
      # @return [ToolRouterConfig]
      def self.function_gemma(collect_traces: false)
        with_model("functiongemma-270m-it-mlx", collect_traces:)
      end

      # Aggressive routing - lower thresholds for faster execution.
      def self.aggressive(model_id)
        new(
          enabled: true,
          model_id:,
          high_confidence_threshold: 0.6,
          low_confidence_threshold: 0.3,
          max_parallel_calls: 5,
          fallback_on_error: true,
          collect_traces: false
        )
      end

      # Conservative routing - higher thresholds, more validation.
      def self.conservative(model_id)
        new(
          enabled: true,
          model_id:,
          high_confidence_threshold: 0.9,
          low_confidence_threshold: 0.7,
          max_parallel_calls: 2,
          fallback_on_error: true,
          collect_traces: true
        )
      end

      def enabled? = enabled
      def disabled? = !enabled
      def has_dispatcher? = enabled && !model_id.nil?
      def fallback_on_error? = fallback_on_error
      def collect_traces? = collect_traces

      # Returns a copy with updated thresholds.
      def with_thresholds(high:, low:)
        with(high_confidence_threshold: high, low_confidence_threshold: low)
      end

      # Returns a copy with trace collection enabled.
      def with_trace_collection
        with(collect_traces: true)
      end
    end
  end
end
