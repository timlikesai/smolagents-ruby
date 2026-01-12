module Smolagents
  module Concerns
    module ToolExecution
      DEFAULT_MAX_TOOL_THREADS = 4

      def self.included(base)
        base.attr_reader :max_tool_threads
      end

      def template_path = nil

      def system_prompt
        Prompts::Presets.tool_calling(
          tools: @tools.values.map(&:to_tool_calling_prompt),
          team: managed_agent_descriptions,
          custom: @custom_instructions
        )
      end

      def execute_step(action_step)
        response = @model.generate(write_memory_to_messages, tools_to_call_from: @tools.values)
        action_step.model_output_message = response
        action_step.token_usage = response.token_usage

        if response.tool_calls&.any?
          tool_outputs = execute_tool_calls(response.tool_calls)
          action_step.tool_calls = response.tool_calls
          action_step.observations = tool_outputs.map(&:observation).join("\n")

          if (final = tool_outputs.find(&:is_final_answer))
            action_step.action_output = final.output
            action_step.is_final_answer = true
          end
        elsif response.content&.length&.positive?
          action_step.observations = response.content
        else
          action_step.error = "No tool calls or content in response"
        end
      end

      private

      def execute_tool_calls(tool_calls)
        return [execute_tool_call(tool_calls.first)] if tool_calls.size == 1

        # Use async execution (fibers when scheduler available, threads as fallback)
        execute_tool_calls_async(tool_calls)
      end

      def execute_tool_calls_parallel(tool_calls)
        pool = ThreadPool.new(@max_tool_threads)
        results = Array.new(tool_calls.size)
        results_mutex = Mutex.new

        threads = tool_calls.each_with_index.map do |tc, idx|
          pool.spawn do
            result = execute_tool_call(tc)
            results_mutex.synchronize { results[idx] = result }
          end
        end

        threads.each(&:join)
        results
      end

      class ThreadPool
        def initialize(max_threads)
          @max_threads = max_threads
          @mutex = Mutex.new
          @available = ConditionVariable.new
          @active = 0
        end

        def spawn
          acquire_slot
          Thread.new do
            yield
          ensure
            release_slot
          end
        end

        private

        def acquire_slot
          @mutex.synchronize do
            @available.wait(@mutex) while @active >= @max_threads
            @active += 1
          end
        end

        def release_slot
          @mutex.synchronize do
            @active -= 1
            @available.signal
          end
        end
      end

      def execute_tool_call(tool_call)
        tool = @tools[tool_call.name]
        return build_tool_output(tool_call, nil, "Unknown tool: #{tool_call.name}") unless tool

        tool.validate_tool_arguments(tool_call.arguments)
        result = tool.call(**tool_call.arguments.transform_keys(&:to_sym))
        is_final = tool_call.name == "final_answer"
        build_tool_output(tool_call, result, "#{tool_call.name}: #{result}", is_final: is_final)
      rescue StandardError => e
        build_tool_output(tool_call, nil, "Error in #{tool_call.name}: #{e.message}")
      end

      def build_tool_output(tool_call, output, observation, is_final: false)
        ToolOutput.from_call(tool_call, output:, observation:, is_final:)
      end
    end
  end
end
