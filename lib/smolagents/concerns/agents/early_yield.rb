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

      def execute_parallel_with_early_yield(tool_calls, &quality_predicate)
        # Shared state for coordinating threads
        results = Array.new(tool_calls.size)
        mutex = Mutex.new
        condition = ConditionVariable.new
        early_result = nil
        completed = 0

        # Spawn all tool calls
        threads = spawn_tool_threads(tool_calls, results, mutex, condition) do |result, _index|
          completed += 1
          # Check if this result is good enough for early yield
          if early_result.nil? && quality_predicate&.call(result)
            early_result = result
            condition.broadcast # Wake up waiting thread
          end
          # Wake up if all complete
          condition.broadcast if completed == tool_calls.size
        end

        # Wait for early result or all complete
        wait_for_early_or_complete(mutex, condition, tool_calls.size) do
          early_result || completed == tool_calls.size
        end

        pending = tool_calls.size - completed
        build_early_yield_result(results, early_result, pending, threads, mutex)
      end

      def spawn_tool_threads(tool_calls, results, mutex, _condition)
        tool_calls.each_with_index.map do |tool_call, index|
          Thread.new do
            result = execute_tool_call(tool_call)
            mutex.synchronize do
              results[index] = result
              yield(result, index)
            end
          end
        end
      end

      def wait_for_early_or_complete(mutex, condition, _total)
        mutex.synchronize do
          until yield
            condition.wait(mutex, 0.1) # 100ms timeout to check periodically
          end
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
