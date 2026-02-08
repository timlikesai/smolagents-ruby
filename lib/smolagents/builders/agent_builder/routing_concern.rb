# frozen_string_literal: true

module Smolagents
  module Builders
    module RoutingConcern
      # Configure a fast dispatcher model for tool routing.
      #
      # The dispatcher provides quick tool predictions before falling
      # back to the primary model. Fully optional - omit for standard
      # behavior using only the primary model.
      #
      # @example With model block
      #   .dispatcher { OpenAIModel.lm_studio("functiongemma-270m-it-mlx") }
      #
      # @example With model instance
      #   .dispatcher(fast_model)
      #
      # @example With model name (auto-configured)
      #   .dispatcher("functiongemma-270m-it-mlx")
      #
      # @param model_or_name [Model, String, nil] Dispatcher model or name
      # @yield Block that returns the dispatcher model
      # @return [AgentBuilder] New builder with dispatcher configured
      def dispatcher(model_or_name = nil, &block)
        if block
          with_config(dispatcher_block: block)
        elsif model_or_name.is_a?(String)
          with_config(dispatcher_model_id: model_or_name)
        elsif model_or_name
          with_config(dispatcher_instance: model_or_name)
        else
          raise ArgumentError, "dispatcher requires a model, model ID, or block"
        end
      end

      # Configure tool routing behavior.
      #
      # @example Conservative routing
      #   .routing(:conservative)
      #
      # @example Aggressive routing (lower thresholds)
      #   .routing(:aggressive)
      #
      # @example Custom config
      #   .routing(high_threshold: 0.85, low_threshold: 0.5)
      #
      # @param preset [Symbol, nil] :conservative, :aggressive, or nil
      # @param high_threshold [Float] High confidence threshold
      # @param low_threshold [Float] Low confidence threshold
      # @param collect_traces [Boolean] Enable training data collection
      # @return [AgentBuilder] New builder with routing config
      def routing(preset = nil, high_threshold: nil, low_threshold: nil, collect_traces: false)
        config = case preset
                 when :conservative then { routing_preset: :conservative }
                 when :aggressive then { routing_preset: :aggressive }
                 when nil
                   { routing_high_threshold: high_threshold,
                     routing_low_threshold: low_threshold,
                     routing_collect_traces: collect_traces }.compact
                 else
                   raise ArgumentError, "Unknown routing preset: #{preset}"
                 end
        with_config(**config)
      end

      # Build the dispatcher model from configuration.
      #
      # @return [Model, nil] Dispatcher model or nil if not configured
      def build_dispatcher_model
        return configuration[:dispatcher_instance] if configuration[:dispatcher_instance]

        if configuration[:dispatcher_block]
          configuration[:dispatcher_block].call
        elsif configuration[:dispatcher_model_id]
          # Auto-create LM Studio model for known IDs
          Models::OpenAIModel.lm_studio(configuration[:dispatcher_model_id])
        end
      end

      # Build the router configuration from builder settings.
      #
      # @param dispatcher [Model] The dispatcher model
      # @return [Types::ToolRouterConfig] Router configuration
      def build_router_config(dispatcher)
        return nil unless dispatcher

        model_id = dispatcher.model_id

        # Start with profile-based config or conservative default
        base_config = Routing::ModelProfiles.config_for(model_id)

        # Apply preset if specified
        case configuration[:routing_preset]
        when :conservative
          base_config = Types::ToolRouterConfig.conservative(model_id)
        when :aggressive
          base_config = Types::ToolRouterConfig.aggressive(model_id)
        end

        # Apply custom thresholds if specified
        if configuration[:routing_high_threshold] || configuration[:routing_low_threshold]
          high = configuration[:routing_high_threshold] || base_config.high_confidence_threshold
          low = configuration[:routing_low_threshold] || base_config.low_confidence_threshold
          base_config = base_config.with_thresholds(high:, low:)
        end

        # Enable trace collection if requested
        if configuration[:routing_collect_traces]
          base_config = base_config.with_trace_collection
        end

        base_config
      end
    end
  end
end
