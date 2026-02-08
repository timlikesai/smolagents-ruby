# frozen_string_literal: true

module Smolagents
  module Routing
    # Routes tool selection using a fast dispatcher model with fallback.
    #
    # The ToolRouter orchestrates tool selection by:
    # 1. Using a fast, small model (e.g., FunctionGemma) to predict tool calls
    # 2. Scoring predictions for confidence
    # 3. Routing based on confidence: execute, validate, or delegate
    # 4. Falling back to primary model when dispatcher fails or is uncertain
    #
    # @example Basic usage with FunctionGemma
    #   router = ToolRouter.new(
    #     dispatcher: OpenAIModel.lm_studio("functiongemma-270m-it-mlx"),
    #     primary: OpenAIModel.lm_studio("gemma-3n-e4b-it-mlx"),
    #     tools: { "search" => search_tool }
    #   )
    #   result = router.route(messages)
    #   result.tool_calls  # => [ToolCall, ...]
    #
    # @example Without dispatcher (uses primary only)
    #   router = ToolRouter.new(primary: model, tools: tools)
    #   result = router.route(messages)  # Goes directly to primary
    #
    class ToolRouter
      include Events::Emitter

      # Result of a routing decision.
      RouteResult = Data.define(
        :tool_calls,
        :source,
        :confidence,
        :latency_ms,
        :fallback_used,
        :trace_id
      ) do
        def from_dispatcher? = source == :dispatcher
        def from_primary? = source == :primary
        def high_confidence? = confidence >= 0.8
      end

      attr_reader :dispatcher, :primary, :tools, :config

      # @param dispatcher [Model, nil] Fast dispatcher model (optional)
      # @param primary [Model] Primary model for validation/fallback
      # @param tools [Hash<String, Tool>] Available tools by name
      # @param config [ToolRouterConfig] Routing configuration
      def initialize(dispatcher: nil, primary:, tools:, config: nil)
        @dispatcher = dispatcher
        @primary = primary
        @tools = tools.transform_keys(&:to_s)
        @config = config || default_config_for(dispatcher)
        @trace_collector = config&.collect_traces? ? Concerns::TraceCollector.default_collector : nil
      end

      # Routes a message to get tool calls.
      #
      # @param messages [Array<ChatMessage>] Conversation messages
      # @param task [String, nil] Task description for tracing
      # @return [RouteResult] Routing result with tool calls
      def route(messages, task: nil)
        return route_via_primary(messages) unless use_dispatcher?

        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        begin
          result = route_via_dispatcher(messages, task:)
          emit :tool_routed, source: result.source, confidence: result.confidence,
                             tool_count: result.tool_calls.size
          result
        rescue StandardError => e
          emit :dispatcher_error, error: e.message
          return route_via_primary(messages, reason: :dispatcher_error) if config.fallback_on_error?

          raise
        ensure
          @last_latency_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
        end
      end

      # Checks if dispatcher would be used.
      def use_dispatcher? = config.enabled? && !dispatcher.nil?

      private

      def route_via_dispatcher(messages, task:)
        # Get dispatcher's prediction
        dispatcher_response = dispatcher.generate(messages, tools: tools.values)
        dispatcher_calls = extract_tool_calls(dispatcher_response)

        return route_via_primary(messages, reason: :no_calls) if dispatcher_calls.empty?

        # Score the predictions
        scored_calls = score_calls(dispatcher_calls)
        min_confidence = scored_calls.map(&:confidence).min

        # Record trace if enabled
        trace_id = record_trace(task:, scored_calls:, min_confidence:)

        # Route based on confidence
        if min_confidence >= config.high_confidence_threshold
          build_result(scored_calls, source: :dispatcher, confidence: min_confidence, trace_id:)
        elsif min_confidence >= config.low_confidence_threshold
          validate_with_primary(messages, scored_calls, trace_id:)
        else
          route_via_primary(messages, reason: :low_confidence, trace_id:)
        end
      end

      def route_via_primary(messages, reason: nil, trace_id: nil)
        response = primary.generate(messages, tools: tools.values)
        calls = extract_tool_calls(response)

        update_trace_outcome(trace_id, validated: true) if trace_id

        build_result(calls, source: :primary, confidence: 1.0, trace_id:,
                     fallback_used: !reason.nil?)
      end

      def validate_with_primary(messages, dispatcher_calls, trace_id:)
        # For medium confidence, we validate dispatcher's choice with primary
        # by asking primary to confirm or override
        response = primary.generate(messages, tools: tools.values)
        primary_calls = extract_tool_calls(response)

        # If primary agrees with dispatcher, boost confidence
        if calls_match?(dispatcher_calls, primary_calls)
          validated_calls = dispatcher_calls.map(&:validate)
          update_trace_outcome(trace_id, validated: true, matched: true)
          build_result(validated_calls, source: :dispatcher, confidence: 0.95, trace_id:)
        else
          update_trace_outcome(trace_id, validated: true, matched: false)
          build_result(primary_calls, source: :primary, confidence: 1.0, trace_id:,
                       fallback_used: true)
        end
      end

      def extract_tool_calls(response)
        return [] unless response.tool_calls&.any?

        response.tool_calls.map do |call|
          Types::SpeculativeToolCall.from_primary(call)
        end
      end

      def score_calls(calls)
        calls.map do |call|
          Models::FunctionGemma::ConfidenceScorer.rescore(call, tools)
        end
      end

      def calls_match?(dispatcher_calls, primary_calls)
        return false if dispatcher_calls.size != primary_calls.size

        dispatcher_names = dispatcher_calls.map(&:name).sort
        primary_names = primary_calls.map(&:name).sort
        dispatcher_names == primary_names
      end

      def build_result(calls, source:, confidence:, trace_id: nil, fallback_used: false)
        # Convert SpeculativeToolCall back to ToolCall for external use
        tool_calls = calls.map do |c|
          c.is_a?(Types::SpeculativeToolCall) ? c.tool_call : c
        end

        RouteResult.new(
          tool_calls:,
          source:,
          confidence:,
          latency_ms: @last_latency_ms || 0,
          fallback_used:,
          trace_id:
        )
      end

      def record_trace(task:, scored_calls:, min_confidence:)
        return nil unless @trace_collector

        prediction = {
          tool_name: scored_calls.first&.name,
          arguments: scored_calls.first&.arguments,
          confidence: min_confidence,
          call_count: scored_calls.size
        }

        trace = @trace_collector.record(
          task: task || "unknown",
          available_tools: tools.keys,
          dispatcher_model: config.model_id,
          prediction:,
          latency_ms: @last_latency_ms || 0
        )
        trace.id
      end

      def update_trace_outcome(trace_id, **outcome)
        return unless @trace_collector && trace_id

        @trace_collector.update_outcome(trace_id, execution_outcome: outcome)
      end

      def default_config_for(dispatcher)
        dispatcher ? Types::ToolRouterConfig.with_model(dispatcher.model_id) : Types::ToolRouterConfig.default
      end
    end
  end
end
