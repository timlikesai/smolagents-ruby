# frozen_string_literal: true

module Smolagents
  module Models
    module FunctionGemma
      # Dispatches tool selection using FunctionGemma as a fast semantic router.
      #
      # Orchestrates the flow: Parse → Score → Route → Execute/Validate
      #
      # Routing logic (based on confidence thresholds):
      # - High (≥0.8): Execute speculatively without primary model validation
      # - Medium (0.5-0.8): Validate with primary model, then execute
      # - Low (<0.5): Delegate entirely to primary model
      #
      # This design trusts semantic intent (which tool to call) while
      # providing guardrails for syntax and argument correctness.
      #
      # @example Basic dispatch
      #   dispatcher = Dispatcher.new(tools:, primary_model:)
      #   result = dispatcher.dispatch(function_gemma_output)
      #   result.action       # => :execute | :validate | :delegate
      #   result.tool_calls   # => [SpeculativeToolCall, ...]
      #
      module Dispatcher
        # Result of dispatch routing decision.
        DispatchResult = Data.define(:action, :tool_calls, :reason) do
          def execute? = action == :execute
          def validate? = action == :validate
          def delegate? = action == :delegate
          def has_calls? = tool_calls.any?
        end

        # Configuration for dispatch thresholds.
        Config = Data.define(
          :high_confidence_threshold,
          :low_confidence_threshold,
          :max_parallel_calls
        ) do
          def self.default
            new(
              high_confidence_threshold: 0.8,
              low_confidence_threshold: 0.5,
              max_parallel_calls: 3
            )
          end
        end

        class << self
          # Dispatches FunctionGemma output to appropriate action.
          #
          # @param raw_output [String] Raw FunctionGemma output
          # @param tools [Hash<String, Tool>] Available tools by name
          # @param config [Config] Dispatch configuration
          # @return [DispatchResult] Routing decision with tool calls
          def dispatch(raw_output, tools:, config: Config.default)
            calls = Parser.parse_speculative(raw_output)
            return empty_result(:delegate, "No tool calls parsed") if calls.empty?

            # Rescore each call based on tool/arg validity
            scored_calls = calls.map { |c| ConfidenceScorer.rescore(c, tools) }

            # Limit parallel calls to prevent runaway execution
            scored_calls = scored_calls.first(config.max_parallel_calls)

            # Route based on lowest confidence (conservative approach)
            min_confidence = scored_calls.map(&:confidence).min
            action, reason = determine_action(min_confidence, config)

            DispatchResult.new(action:, tool_calls: scored_calls, reason:)
          end

          # Dispatches and returns only executable calls.
          #
          # @param raw_output [String] Raw FunctionGemma output
          # @param tools [Hash<String, Tool>] Available tools
          # @param config [Config] Dispatch configuration
          # @return [Array<SpeculativeToolCall>] Executable calls (may be empty)
          def executable_calls(raw_output, tools:, config: Config.default)
            result = dispatch(raw_output, tools:, config:)
            return [] unless result.execute?

            result.tool_calls.select(&:executable?)
          end

          # Checks if output contains high-confidence tool calls.
          #
          # @param raw_output [String] Raw FunctionGemma output
          # @param tools [Hash<String, Tool>] Available tools
          # @return [Boolean] True if all calls are high confidence
          def high_confidence?(raw_output, tools:)
            result = dispatch(raw_output, tools:)
            result.execute? && result.has_calls?
          end

          private

          def determine_action(min_confidence, config)
            if min_confidence >= config.high_confidence_threshold
              [:execute, "All calls above high confidence threshold"]
            elsif min_confidence >= config.low_confidence_threshold
              [:validate, "Some calls need primary model validation"]
            else
              [:delegate, "Low confidence - delegating to primary model"]
            end
          end

          def empty_result(action, reason)
            DispatchResult.new(action:, tool_calls: [], reason:)
          end
        end
      end
    end
  end
end
