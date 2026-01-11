module Smolagents
  module Concerns
    module ToolExecution
      DEFAULT_MAX_TOOL_THREADS = 4

      def self.included(base)
        base.attr_reader :max_tool_threads
      end

      private

      def execute_tool_calls(tool_calls)
        return [execute_tool_call(tool_calls.first)] if tool_calls.size == 1
        execute_tool_calls_parallel(tool_calls)
      end

      def execute_tool_calls_parallel(tool_calls)
        results_mutex = Mutex.new
        results = Array.new(tool_calls.size)
        pool_mutex = Mutex.new
        pool_available = ConditionVariable.new
        active_threads = 0

        threads = tool_calls.each_with_index.map do |tc, index|
          pool_mutex.synchronize do
            pool_available.wait(pool_mutex) while active_threads >= @max_tool_threads
            active_threads += 1
          end

          Thread.new(tc, index) do |tool_call, idx|
            result = execute_tool_call(tool_call)
            results_mutex.synchronize { results[idx] = result }
          ensure
            pool_mutex.synchronize do
              active_threads -= 1
              pool_available.signal
            end
          end
        end

        threads.each(&:join)
        results
      end

      def execute_tool_call(tool_call)
        tool = @tools[tool_call.name]
        return build_tool_output(tool_call, nil, "Error: Unknown tool '#{tool_call.name}'") unless tool

        begin
          tool.validate_tool_arguments(tool_call.arguments)
          result = tool.call(**tool_call.arguments.transform_keys(&:to_sym))
          build_tool_output(tool_call, result, "Tool '#{tool_call.name}' returned: #{result}", is_final: tool_call.name == "final_answer")
        rescue StandardError => e
          @logger.warn("Tool execution error", tool: tool_call.name, error: e.message)
          build_tool_output(tool_call, nil, "Error executing '#{tool_call.name}': #{e.message}")
        end
      end

      def build_tool_output(tool_call, output, observation, is_final: false)
        ToolOutput.new(id: tool_call.id, output: output, is_final_answer: is_final, observation: observation, tool_call: tool_call)
      end
    end
  end
end
