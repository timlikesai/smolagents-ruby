require_relative "error_feedback"
require_relative "prompt_generation"
require_relative "thread_pool"

module Smolagents
  module Concerns
    # Executes tool calls from model responses.
    #
    # Integrates with the event system to emit ToolCallRequested and
    # ToolCallCompleted events, enabling non-blocking orchestration
    # and monitoring.
    #
    # @example Basic execution
    #   agent.execute_tool_call(tool_call)
    #
    # @example With event queue connected
    #   agent.connect_to(event_queue)
    #   agent.execute_tool_call(tool_call)  # Emits events
    #
    module ToolExecution
      # @return [Integer] Default maximum concurrent threads for tool execution.
      DEFAULT_MAX_TOOL_THREADS = 4

      def self.included(base)
        base.include(Events::Emitter)
        base.include(ErrorFeedback)
        base.include(PromptGeneration)
        base.attr_reader :max_tool_threads
      end

      # Execute a single agent step with tool calling.
      #
      # Generates a response from the model, executes any tool calls,
      # and updates the action step with results. Handles final answers
      # and error cases.
      #
      # @param action_step [ActionStep] Step to populate with results
      # @return [void] Updates action_step in place
      #
      # @example
      #   step = ActionStep.new(step_number: 1)
      #   agent.execute_step(step)
      #   # step now contains model output, tool calls, and observations
      def execute_step(action_step)
        response = @model.generate(write_memory_to_messages, tools_to_call_from: @tools.values)
        action_step.model_output_message = response
        action_step.token_usage = response.token_usage
        process_response(action_step, response)
      end

      private

      def process_response(step, response)
        if response.tool_calls&.any? then process_tool_calls(step, response)
        elsif response.content&.length&.positive? then step.observations = response.content
        else step.error = "No tool calls or content in response"
        end
      end

      def process_tool_calls(step, response)
        outputs = execute_tool_calls(response.tool_calls)
        step.tool_calls = response.tool_calls
        step.observations = outputs.map(&:observation).join("\n")
        return unless (final = outputs.find(&:is_final_answer))

        step.action_output = final.output
        step.is_final_answer = true
      end

      def execute_tool_calls(tool_calls)
        return [execute_tool_call(tool_calls.first)] if tool_calls.size == 1

        # Use async execution (fibers when scheduler available, threads as fallback)
        execute_tool_calls_async(tool_calls)
      end

      def execute_tool_calls_parallel(tool_calls)
        pool = ThreadPool.new(@max_tool_threads)
        results = Array.new(tool_calls.size)
        mutex = Mutex.new
        threads = tool_calls.each_with_index.map do |tc, idx|
          pool.spawn { mutex.synchronize { results[idx] = execute_tool_call(tc) } }
        end
        threads.each(&:join)
        results
      end

      def execute_tool_call(tool_call)
        tool = @tools[tool_call.name]
        return build_tool_output(tool_call, nil, "Unknown tool: #{tool_call.name}") unless tool

        run_validated_tool_call(tool, tool_call)
      rescue FinalAnswerException => e
        # FinalAnswerException is control flow, not an error - extract the value
        build_tool_output(tool_call, e.value, "final_answer: #{e.value}", is_final: true)
      rescue StandardError => e
        handle_tool_error(e, tool_call)
      end

      def run_validated_tool_call(tool, tool_call)
        request_event = emit_event(Events::ToolCallRequested.create(tool_name: tool_call.name,
                                                                    args: tool_call.arguments))
        tool.validate_tool_arguments(tool_call.arguments)
        result = tool.call(**tool_call.arguments.transform_keys(&:to_sym))
        emit_tool_completed(request_event&.id, tool_call, result)
        build_tool_output(tool_call, result, "#{tool_call.name}: #{result}", is_final: tool_call.name == "final_answer")
      end

      def handle_tool_error(error, tool_call)
        emit_error(error, context: { tool_name: tool_call.name, arguments: tool_call.arguments }, recoverable: true)
        build_tool_output(tool_call, nil, format_error_feedback(error, tool_call))
      end

      def emit_tool_completed(request_id, tool_call, result)
        observation = "#{tool_call.name}: #{result}"
        emit_event(Events::ToolCallCompleted.create(request_id:, tool_name: tool_call.name, result:, observation:,
                                                    is_final: tool_call.name == "final_answer"))
      end

      def build_tool_output(tool_call, output, observation, is_final: false)
        ToolOutput.from_call(tool_call, output:, observation:, is_final:)
      end
    end
  end
end
