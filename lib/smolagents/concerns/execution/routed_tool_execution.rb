# frozen_string_literal: true

module Smolagents
  module Concerns
    # Tool execution with optional fast routing.
    #
    # Extends NativeToolExecution to use a fast dispatcher model when
    # configured. Falls back gracefully to primary model on any issue.
    #
    # == Execution Flow
    #
    # 1. If router enabled and dispatcher available:
    #    a. Route through dispatcher for fast tool prediction
    #    b. If high confidence → execute tools directly
    #    c. If medium confidence → validate with primary
    #    d. If low confidence → delegate to primary
    # 2. If router disabled or fails → standard NativeToolExecution
    #
    # This is transparent - agents work the same with or without routing.
    #
    module RoutedToolExecution
      include NativeToolExecution

      # ToolRouting is included dynamically to avoid load order issues
      def self.included(base)
        base.include(Events::Emitter) unless base < Events::Emitter
        base.include(BudgetTracking) unless base < BudgetTracking
        # Defer ToolRouting inclusion until runtime
      end

      # Lazily include ToolRouting when first needed
      def tool_routing_enabled?
        extend_with_tool_routing unless @_tool_routing_extended
        @tool_router&.use_dispatcher? || false
      end

      def route_tool_selection(messages, action_step)
        extend_with_tool_routing unless @_tool_routing_extended
        return nil unless tool_routing_enabled?

        result = @tool_router.route(messages, task: extract_task(messages))
        record_routing_result(action_step, result)
        result
      rescue StandardError => e
        emit :tool_routing_error, error: e.message, fallback: :primary
        nil
      end

      def initialize_tool_routing(dispatcher_model: nil, router_config: nil)
        @dispatcher_model = dispatcher_model
        @router_config = router_config
        @tool_router = build_tool_router
        @_tool_routing_extended = true
      end

      # Execute step with optional routing.
      #
      # @param action_step [ActionStepBuilder] Step to update
      # @return [void]
      def execute_native_step(action_step)
        if tool_routing_enabled?
          execute_routed_step(action_step)
        else
          super # Standard NativeToolExecution
        end
      end

      private

      def extend_with_tool_routing
        @_tool_routing_extended = true
        # Router already built or not configured
      end

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
        profile = Routing::ModelProfiles.for(dispatcher.model_id)
        if profile
          profile.to_config.with(model_id: dispatcher.model_id)
        else
          Types::ToolRouterConfig.conservative(dispatcher.model_id)
        end
      end

      def record_routing_result(action_step, result)
        return unless result

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
        user_msg = messages.reverse.find { |m| m.role.to_sym == :user }
        user_msg&.content&.slice(0, 200) || "unknown"
      end

      def execute_routed_step(action_step)
        messages = write_memory_to_messages
        result = route_tool_selection(messages, action_step)

        if result&.tool_calls&.any?
          process_routed_tool_calls(action_step, result)
        else
          # Routing returned nothing or failed - fall back to primary
          execute_primary_step(action_step, messages)
        end
      end

      def process_routed_tool_calls(action_step, result)
        tool_calls = result.tool_calls
        results = tool_calls.map { |tc| run_tool(tc) }

        action_step.tool_calls = tool_calls
        action_step.model_output_message = build_routed_message(tool_calls, result)

        final = results.find { |r| r[:name] == "final_answer" }
        action_step.final_answer = final[:result] if final
        action_step.observations = format_tool_results(results)
      end

      def execute_primary_step(action_step, messages)
        response = with_generation_timeout(context: :native_tool) do
          @model.generate(messages, tools_to_call_from: @tools.values, stop_sequences: nil)
        end

        action_step.model_output_message = response
        action_step.token_usage = response.token_usage

        if response.tool_calls&.any?
          process_tool_calls(action_step, response.tool_calls)
        else
          action_step.final_answer = response.content
          action_step.observations = response.content
        end
      end

      def build_routed_message(tool_calls, result)
        # Create a synthetic message representing the routed result
        Types::ChatMessage.new(
          role: :assistant,
          content: "",
          tool_calls:,
          raw: { routing_source: result.source, routing_confidence: result.confidence },
          token_usage: nil,
          images: nil,
          reasoning_content: nil
        )
      end
    end
  end
end
