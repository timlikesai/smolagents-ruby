module Smolagents
  module Concerns
    module AsyncTools
      AsyncResult = Data.define(:index, :value, :error) do
        def success? = error.nil?
        def failure? = !success?
      end

      def execute_tool_calls_async(tool_calls)
        return [execute_tool_call(tool_calls.first)] if tool_calls.size == 1
        return execute_tool_calls_parallel(tool_calls) unless fiber_scheduler_available?

        execute_tool_calls_with_fibers(tool_calls)
      end

      private

      def fiber_scheduler_available?
        !!(Fiber.scheduler && Fiber.scheduler.respond_to?(:run))
      end

      def execute_tool_calls_with_fibers(tool_calls)
        results = Array.new(tool_calls.size)
        fibers = schedule_tool_fibers(tool_calls, results)
        collect_fiber_results(fibers, results)
      end

      def schedule_tool_fibers(tool_calls, results)
        tool_calls.each_with_index.map do |tool_call, index|
          Fiber.schedule do
            results[index] = execute_tool_call_async(tool_call, index)
          end
        end
      end

      def execute_tool_call_async(tool_call, index)
        result = execute_tool_call(tool_call)
        AsyncResult.new(index: index, value: result, error: nil)
      rescue StandardError => e
        AsyncResult.new(index: index, value: nil, error: e)
      end

      def collect_fiber_results(fibers, results)
        wait_for_fibers(fibers)
        process_async_results(results)
      end

      def wait_for_fibers(fibers)
        fibers.compact.each do |fiber|
          fiber.resume if fiber.respond_to?(:alive?) && fiber.alive?
        rescue FiberError
          # Fiber already resumed by scheduler
        end
      end

      def process_async_results(results)
        results.map do |result|
          case result
          in AsyncResult[value:, error: nil]
            value
          in AsyncResult[index:, error:]
            build_error_output(index, error)
          in ToolOutput
            result
          else
            raise AsyncExecutionError, "Unexpected result type: #{result.class}"
          end
        end
      end

      def build_error_output(index, error)
        ToolOutput.new(
          id: "async_error_#{index}",
          output: nil,
          is_final_answer: false,
          observation: "Async execution error: #{error.message}",
          tool_call: nil
        )
      end
    end

    class AsyncExecutionError < StandardError; end
  end
end
