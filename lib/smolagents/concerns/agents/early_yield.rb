module Smolagents
  module Concerns
    # Early yield execution for parallel tool calls.
    #
    # Enables returning results as soon as one "good enough" result arrives,
    # rather than waiting for all parallel tool calls to complete. Based on
    # speculative execution patterns from distributed systems research.
    #
    # @example Basic usage
    #   results = execute_with_early_yield(tool_calls) { |r| r.success? }
    #   # Returns as soon as first successful result arrives
    #
    # @example With quality threshold
    #   results = execute_with_early_yield(tool_calls) do |result|
    #     result.success? && result.output.to_s.length > 100
    #   end
    #
    # @see AsyncTools For base async execution
    # @see http://arxiv.org/abs/2203.16487v6 Speculative Decoding paper
    module EarlyYield
      # Result from early yield execution.
      #
      # Contains the early result(s) that triggered yield, plus a callback
      # to collect remaining results later if needed.
      #
      # @!attribute [r] results
      #   @return [Array<ToolOutput>] Results available at yield time
      # @!attribute [r] early_result
      #   @return [ToolOutput, nil] The result that triggered early yield
      # @!attribute [r] pending_count
      #   @return [Integer] Number of tool calls still in progress
      EarlyYieldResult = Data.define(:results, :early_result, :pending_count, :collector) do
        # Check if this was an early yield (not all results collected)
        # @return [Boolean]
        def early? = pending_count.positive?

        # Check if all results are complete
        # @return [Boolean]
        def complete? = pending_count.zero?

        # Collect remaining results (blocks until all complete).
        # Safe to call multiple times - returns cached results.
        # @return [Array<ToolOutput>] All results including late arrivals
        def collect_remaining
          return results if complete?

          collector&.call || results
        end
      end

      # Execute tool calls with early yield on first acceptable result.
      #
      # Runs all tool calls in parallel. When the quality_predicate block
      # returns true for a result, immediately returns that result along
      # with any others that have completed. Remaining results can be
      # collected later via the returned object.
      #
      # @param tool_calls [Array<ToolCall>] Tool calls to execute in parallel
      # @yield [ToolOutput] Called for each completed result to check quality
      # @yieldreturn [Boolean] true to accept result and yield early
      # @return [EarlyYieldResult] Results with early yield metadata
      #
      # @example
      #   result = execute_with_early_yield(tool_calls) do |output|
      #     output.success? && !output.observation.include?("error")
      #   end
      #
      #   if result.early?
      #     # Got good result early, can continue without waiting
      #     process(result.early_result)
      #     # Optionally collect remaining later
      #     all_results = result.collect_remaining
      #   end
      def execute_with_early_yield(tool_calls, &)
        return wrap_single_result(tool_calls.first) if tool_calls.size == 1

        execute_parallel_with_early_yield(tool_calls, &)
      end

      private

      def wrap_single_result(tool_call)
        result = execute_tool_call(tool_call)
        EarlyYieldResult.new(
          results: [result],
          early_result: result,
          pending_count: 0,
          collector: nil
        )
      end

      def execute_parallel_with_early_yield(tool_calls, &)
        state = ParallelExecutionState.new(tool_calls.size)

        threads = spawn_monitored_threads(tool_calls, state, &)
        wait_for_early_or_complete(state.mutex, state.condition) { state.should_yield? }

        build_early_yield_result(state.results, state.early_result, state.pending_count, threads, state.mutex)
      end

      # Shared state for parallel execution with early yield.
      # Uses mutable state wrapped in Struct since Data.define is immutable.
      class ParallelExecutionState
        attr_reader :total, :results, :mutex, :condition
        attr_accessor :early_result, :completed

        def initialize(total)
          @total = total
          @results = Array.new(total)
          @mutex = Mutex.new
          @condition = ConditionVariable.new
          @early_result = nil
          @completed = 0
        end

        def should_yield? = early_result || completed == total
        def pending_count = total - completed
      end

      def spawn_monitored_threads(tool_calls, state, &)
        tool_calls.each_with_index.map { |tool_call, index| spawn_monitored_thread(tool_call, index, state, &) }
      end

      def spawn_monitored_thread(tool_call, index, state, &)
        Thread.new do
          result = execute_tool_call(tool_call)
          state.mutex.synchronize { record_result(result, index, state, &) }
        end
      end

      def record_result(result, index, state, &quality_predicate)
        state.results[index] = result
        state.completed += 1
        check_early_yield(result, state, &quality_predicate) if quality_predicate
        state.condition.broadcast if state.should_yield?
      end

      def check_early_yield(result, state)
        return if state.early_result || !yield(result)

        state.early_result = result
      end

      def wait_for_early_or_complete(mutex, condition)
        mutex.synchronize do
          condition.wait(mutex, 0.1) until yield
        end
      end

      def build_early_yield_result(results, early_result, pending, threads, mutex)
        # Collector lambda to gather remaining results
        collector = lambda do
          threads.each(&:join) # Wait for all threads
          mutex.synchronize { results.compact }
        end

        EarlyYieldResult.new(
          results: mutex.synchronize { results.compact },
          early_result:,
          pending_count: pending,
          collector:
        )
      end
    end
  end
end
