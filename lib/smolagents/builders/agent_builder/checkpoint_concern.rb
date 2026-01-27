module Smolagents
  module Builders
    # Checkpoint and semantic breaker configuration for AgentBuilder.
    #
    # Provides DSL methods for configuring state checkpointing and
    # semantic circuit breaker behavior.
    module AgentCheckpointConcern
      # Enable checkpointing for state recovery and debugging.
      # @param max [Integer] Maximum checkpoints to retain (default: 10)
      # @param interval [Integer, nil] Steps between auto-checkpoints
      # @param path [String, nil] Directory for persistent storage
      # @return [AgentBuilder] New builder with checkpoints configured
      def with_checkpoints(max: 10, interval: nil, path: nil)
        check_frozen!
        config = build_checkpoint_config(max, interval, path)
        with_config(checkpoint_config: config)
      end

      # Disable checkpointing (default is disabled).
      # @return [AgentBuilder] New builder with checkpoints disabled
      def without_checkpoints
        check_frozen!
        with_config(checkpoint_config: Types::CheckpointConfig.disabled)
      end

      # Enable semantic circuit breaker for failure detection.
      # Detects goal drift, confidence decay, and reasoning loops.
      # @param preset [Symbol] :default, :strict, or :permissive
      # @param threshold [Integer] Consecutive failures before breaking (default: 3)
      # @return [AgentBuilder] New builder with semantic breaker configured
      def with_semantic_breaker(preset = :default, threshold: 3)
        check_frozen!
        config = semantic_config_for_preset(preset)
        with_config(semantic_config: config, semantic_failure_threshold: threshold)
      end

      private

      def build_checkpoint_config(max, interval, path)
        return Types::CheckpointConfig.persistent(path:, interval: interval || 5, max_checkpoints: max) if path
        return Types::CheckpointConfig.auto(interval:, max_checkpoints: max) if interval

        Types::CheckpointConfig.default.with(max_checkpoints: max)
      end

      def semantic_config_for_preset(preset)
        case preset
        when :strict then Types::SemanticDetectionConfig.strict
        when :permissive then Types::SemanticDetectionConfig.permissive
        else Types::SemanticDetectionConfig.default
        end
      end

      # Configure checkpointing for state recovery.
      def configure_checkpoints(agent)
        config = configuration[:checkpoint_config]
        return unless config&.enabled?

        agent.setup_checkpoints(config)
      end

      # Configure semantic circuit breaker for failure detection.
      def configure_semantic_breaker(agent)
        config = configuration[:semantic_config]
        return unless config

        threshold = configuration[:semantic_failure_threshold]
        agent.setup_semantic_breaker(config, failure_threshold: threshold)
      end
    end
  end
end
