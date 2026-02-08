# frozen_string_literal: true

module Smolagents
  module Concerns
    module Agents
      # Optional tool routing via fast dispatcher models.
      #
      # Wraps native tool execution to route through a fast dispatcher
      # (e.g., FunctionGemma, LFM) before falling back to the primary model.
      # Fully optional - if not configured, uses primary model directly.
      #
      # == Sensible Defaults
      #
      # - No dispatcher configured → Uses primary model (no overhead)
      # - Dispatcher fails → Falls back to primary model
      # - Low confidence → Validates with or delegates to primary
      # - Tracing disabled by default → Opt-in for training data
      #
      # @example Enable with FunctionGemma
      #   agent = Smolagents.agent
      #     .model { primary_model }
      #     .dispatcher { fast_model }
      #     .tools(:search)
      #     .build
      #
      module ToolRouting
        def self.included(base)
          base.include(Events::Emitter) unless base < Events::Emitter
        end

        # Initialize tool routing infrastructure.
        #
        # @param dispatcher_model [Model, nil] Fast dispatcher (nil = disabled)
        # @param router_config [ToolRouterConfig, nil] Custom config (nil = auto)
        def initialize_tool_routing(dispatcher_model: nil, router_config: nil)
          @dispatcher_model = dispatcher_model
          @router_config = router_config
          @tool_router = build_tool_router
        end

        # Check if tool routing is active.
        def tool_routing_enabled?
          @tool_router&.use_dispatcher? || false
        end

        # Route tool selection, with fallback to primary model.
        #
        # @param messages [Array<ChatMessage>] Conversation messages
        # @param action_step [ActionStepBuilder] Step to update
        # @return [RouteResult, nil] Routing result or nil if disabled
        def route_tool_selection(messages, action_step)
          return nil unless tool_routing_enabled?

          result = @tool_router.route(messages, task: extract_task(messages))
          record_routing_result(action_step, result)
          result
        rescue StandardError => e
          emit :tool_routing_error, error: e.message, fallback: :primary
          nil # Signal to use primary model directly
        end

        private

        def build_tool_router
          return nil unless @dispatcher_model

          config = @router_config || auto_config_for(@dispatcher_model)
          Routing::ToolRouter.new(
            dispatcher: @dispatcher_model,
            primary: @model,
            tools: @tools,
            config:
          )
        end

        def auto_config_for(dispatcher)
          # Use empirical profiles if available, otherwise conservative defaults
          profile = Routing::ModelProfiles.for(dispatcher.model_id)
          if profile
            profile.to_config.with(model_id: dispatcher.model_id)
          else
            Types::ToolRouterConfig.conservative(dispatcher.model_id)
          end
        end

        def record_routing_result(action_step, result)
          return unless result

          # Store routing metadata in step for observability
          action_step.instance_variable_set(:@routing_source, result.source)
          action_step.instance_variable_set(:@routing_confidence, result.confidence)
          action_step.instance_variable_set(:@routing_fallback_used, result.fallback_used)

          emit :tool_routing_completed,
               source: result.source,
               confidence: result.confidence,
               fallback_used: result.fallback_used,
               tool_count: result.tool_calls.size,
               latency_ms: result.latency_ms
        end

        def extract_task(messages)
          # Find the user's task from messages
          user_msg = messages.reverse.find { |m| m.role.to_sym == :user }
          user_msg&.content&.slice(0, 200) || "unknown"
        end
      end
    end
  end
end
