module Smolagents
  module Concerns
    # Async tool execution using Ruby Fibers or thread pools.
    #
    # Provides non-blocking execution of multiple tool calls concurrently.
    # Uses Ruby 3.0+ Fiber.scheduler when available, falls back to threads.
    #
    # @example Single tool call (no async overhead)
    #   results = execute_tool_calls_async([tool_call])
    #   # => Direct execution without fiber/thread creation
    #
    # @example Multiple concurrent calls
    #   results = execute_tool_calls_async([tc1, tc2, tc3])
    #   # Executes concurrently via Fiber.scheduler (Ruby 3.0+)
    #   # or thread pool (fallback)
    #
    # @see ToolExecution For tool call invocation
    module AsyncTools
      # Result wrapper for async execution with index tracking
      #
      # Immutable Data class tracking whether async execution succeeded
      # or failed, with the result value and any error.
      #
      # @!attribute [r] index
      #   @return [Integer] Position in original tool_calls array
      # @!attribute [r] value
      #   @return [Object] Result value on success, nil on failure
      # @!attribute [r] error
      #   @return [StandardError, nil] Error object on failure, nil on success
      AsyncResult = Data.define(:index, :value, :error) do
        # Create a successful result
        # @param index [Integer] Position in tool_calls array
        # @param value [Object] Result value
        # @return [AsyncResult] Success result
        def self.success(index:, value:) = new(index:, value:, error: nil)

        # Create a failed result
        # @param index [Integer] Position in tool_calls array
        # @param error [StandardError] Error that occurred
        # @return [AsyncResult] Failure result
        def self.failure(index:, error:) = new(index:, value: nil, error:)

        # Check if execution succeeded
        # @return [Boolean] true if no error occurred
        def success? = error.nil?

        # Check if execution failed
        # @return [Boolean] true if error occurred
        def failure? = !success?
      end

      # Execute multiple tool calls asynchronously
      #
      # Detects best execution strategy:
      # 1. Single call: Direct execution (no async overhead)
      # 2. Fiber scheduler available: Use Fiber.schedule (non-blocking)
      # 3. Fallback: Thread pool execution
      #
      # @param tool_calls [Array<ToolCall>] Tool calls to execute
      # @return [Array<ToolOutput>] Results in original order
      # @see #fiber_scheduler_available? For scheduler detection
      def execute_tool_calls_async(tool_calls)
        return [execute_tool_call(tool_calls.first)] if tool_calls.size == 1
        return execute_tool_calls_parallel(tool_calls) unless fiber_scheduler_available?

        execute_tool_calls_with_fibers(tool_calls)
      end

      private

      # Check if a Fiber scheduler is available for cooperative multitasking
      # @return [Boolean] true if Fiber.scheduler exists and responds to :run
      # @api private
      def fiber_scheduler_available?
        !!(Fiber.scheduler && Fiber.scheduler.respond_to?(:run))
      end

      # Execute tool calls using Ruby Fibers for non-blocking concurrency
      # @param tool_calls [Array<ToolCall>] Tool calls to execute
      # @return [Array<ToolOutput>] Results in original order
      # @api private
      def execute_tool_calls_with_fibers(tool_calls)
        results = Array.new(tool_calls.size)
        fibers = schedule_tool_fibers(tool_calls, results)
        collect_fiber_results(fibers, results)
      end

      # Schedule Fiber for each tool call
      # @param tool_calls [Array<ToolCall>] Tool calls to schedule
      # @param results [Array] Shared results array to store outputs
      # @return [Array<Fiber>] Created fibers
      # @api private
      def schedule_tool_fibers(tool_calls, results)
        tool_calls.each_with_index.map do |tool_call, index|
          Fiber.schedule do
            results[index] = execute_tool_call_async(tool_call, index)
          end
        end
      end

      # Execute a single tool call within a Fiber context
      # @param tool_call [ToolCall] The tool call to execute
      # @param index [Integer] Position in results array
      # @return [AsyncResult] Wrapped result or error
      # @api private
      def execute_tool_call_async(tool_call, index)
        AsyncResult.success(index:, value: execute_tool_call(tool_call))
      rescue StandardError => e
        AsyncResult.failure(index:, error: e)
      end

      # Collect results from all fibers
      # @param fibers [Array<Fiber>] Fibers to wait for
      # @param results [Array<AsyncResult>] Results filled by fibers
      # @return [Array<ToolOutput>] Processed results
      # @api private
      def collect_fiber_results(fibers, results)
        wait_for_fibers(fibers)
        process_async_results(results)
      end

      # Wait for all fibers to complete
      # @param fibers [Array<Fiber>] Fibers to resume
      # @api private
      def wait_for_fibers(fibers)
        fibers.compact.each do |fiber|
          fiber.resume if fiber.respond_to?(:alive?) && fiber.alive?
        rescue FiberError
          # Fiber already resumed by scheduler
        end
      end

      # Process async execution results and convert to ToolOutput
      # @param results [Array<AsyncResult, ToolOutput>] Mixed results from async execution
      # @return [Array<ToolOutput>] Standardized tool outputs
      # @raise [AsyncExecutionError] If result type is unexpected
      # @api private
      def process_async_results(results)
        results.map { |result| unwrap_async_result(result) }
      end

      def unwrap_async_result(result)
        case result
        in AsyncResult[value:, error: nil] then value
        in AsyncResult[index:, error:] then build_error_output(index, error)
        in ToolOutput then result
        else raise AsyncExecutionError, "Unexpected result type: #{result.class}"
        end
      end

      # Build error output for a failed async tool call
      # @param index [Integer] Position in tool_calls array
      # @param error [StandardError] The error that occurred
      # @return [ToolOutput] Error output
      # @api private
      def build_error_output(index, error)
        ToolOutput.error(id: "async_error_#{index}", observation: "Async execution error: #{error.message}")
      end
    end

    # Raised when async tool execution encounters an unexpected result type
    # @!visibility private
    class AsyncExecutionError < StandardError; end
  end
end
