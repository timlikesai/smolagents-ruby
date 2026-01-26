require_relative "../fiber_execution"
require_relative "../tool_future"

module Smolagents
  module Executors
    class Executor
      # Tracks tool calls and returns ToolFutures for lazy evaluation.
      #
      # Every tool call:
      # 1. Records the call (name, args, result, timing)
      # 2. Yields a ToolYield back to the orchestrator
      # 3. Returns the result to the agent code
      #
      # This is THE mechanism that enables agents to think in code while
      # the orchestrator observes and controls execution.
      #
      # @example Tool calls yield to orchestrator
      #   # Agent code:
      #   results = search(query: "Ruby")  # Yields here!
      #   # Orchestrator sees results, decides to continue
      #   best = results.first
      #
      module ToolCallTracking
        # Recorded tool call data.
        TrackedCall = Data.define(:tool_name, :arguments, :result, :duration, :error) do
          def success? = error.nil?
          def to_h = { tool_name:, arguments:, result:, duration:, error: }
        end

        def self.included(base)
          base.attr_reader :tool_calls
        end

        # Clears tracked tool calls before execution.
        # @return [void]
        def clear_tool_calls
          @tool_calls = []
        end

        # Returns recorded tool calls from the last execution.
        # @return [Array<TrackedCall>]
        def tool_calls
          @tool_calls ||= []
        end

        private

        def initialize_tool_call_tracking
          @tool_calls = []
        end

        # Wraps tools in tracking proxies.
        # @param tools [Hash{String => Tool}] Tools to wrap
        # @return [Hash{String => TrackedToolProxy}]
        def wrap_tools_for_tracking(tools)
          tools.transform_values { |tool| TrackedToolProxy.new(tool, self) }
        end

        # Records a tool call.
        # @api private
        def record_tool_call(tool_name:, arguments:, result:, duration:, error: nil)
          @tool_calls ||= []
          @tool_calls << TrackedCall.new(tool_name:, arguments:, result:, duration:, error:)
        end
      end

      # Proxy that returns ToolFutures for lazy evaluation.
      #
      # Tool calls return immediately with a ToolFuture. The actual execution
      # is deferred until the result is accessed, enabling automatic batching
      # and parallel execution of multiple tool calls.
      #
      # @api private
      class TrackedToolProxy
        def initialize(tool, tracker)
          @tool = tool
          @tracker = tracker
        end

        def call(*args, **kwargs)
          arguments = kwargs.empty? && args.any? ? { args: } : kwargs
          tool_name = tool_name_for_tracking
          executor = build_executor(tool_name, arguments, args, kwargs)
          ToolFuture.new(tool_name:, arguments:, executor:)
        end

        def build_executor(tool_name, arguments, args, kwargs)
          -> { execute_and_record(tool_name, arguments, args, kwargs) }
        end

        def execute_and_record(tool_name, arguments, args, kwargs)
          start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          result = nil
          error = nil
          result = @tool.call(*args, **kwargs)
          result
        rescue StandardError => e
          error = e.message
          raise
        ensure
          record_call(tool_name:, arguments:, result:, error:, duration: elapsed(start))
        end

        private

        def record_call(tool_name:, arguments:, result:, error:, duration:)
          @tracker.send(:record_tool_call, tool_name:, arguments:, result:, duration:, error:)
        end

        def elapsed(start) = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start

        def tool_name_for_tracking
          return @tool.name if @tool.respond_to?(:name)
          return @tool.tool_name if @tool.respond_to?(:tool_name)

          @tool.class.name || "unknown"
        end

        # Forward other methods to the underlying tool
        def method_missing(method, *, &) = @tool.public_send(method, *, &)
        def respond_to_missing?(method, include_private = false) = @tool.respond_to?(method, include_private)
      end
    end
  end
end
