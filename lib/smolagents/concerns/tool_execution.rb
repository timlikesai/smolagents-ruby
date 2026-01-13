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
      DEFAULT_MAX_TOOL_THREADS = 4

      def self.included(base)
        base.include(Events::Emitter)
        base.attr_reader :max_tool_threads
      end

      def template_path = nil

      def system_prompt
        base_prompt = Prompts::Presets.tool_calling(
          tools: @tools.values.map(&:to_tool_calling_prompt),
          team: managed_agent_descriptions,
          custom: @custom_instructions
        )
        capabilities = capabilities_prompt
        capabilities.empty? ? base_prompt : "#{base_prompt}\n\n#{capabilities}"
      end

      # Generates capabilities prompt showing tool call patterns.
      # @return [String] Capabilities prompt addendum
      def capabilities_prompt
        Prompts.generate_capabilities(
          tools: @tools,
          managed_agents: @managed_agents,
          agent_type: :tool_calling
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

      # Simple thread pool - no blocking waits, just tracks active count
      class ThreadPool
        def initialize(max_threads)
          @max_threads = max_threads
          @mutex = Mutex.new
          @active = 0
        end

        def spawn
          # Just spawn thread immediately - no blocking wait for slots
          @mutex.synchronize { @active += 1 }
          Thread.new do
            yield
          ensure
            @mutex.synchronize { @active -= 1 }
          end
        end
      end

      def execute_tool_call(tool_call)
        tool = @tools[tool_call.name]
        return build_tool_output(tool_call, nil, "Unknown tool: #{tool_call.name}") unless tool

        # Emit request event (if connected to queue)
        request_event = emit_event(Events::ToolCallRequested.create(
                                     tool_name: tool_call.name,
                                     args: tool_call.arguments
                                   ))

        tool.validate_tool_arguments(tool_call.arguments)
        result = tool.call(**tool_call.arguments.transform_keys(&:to_sym))
        is_final = tool_call.name == "final_answer"
        observation = "#{tool_call.name}: #{result}"

        # Emit completion event
        emit_event(Events::ToolCallCompleted.create(
                     request_id: request_event&.id,
                     tool_name: tool_call.name,
                     result: result,
                     observation: observation,
                     is_final: is_final
                   ))

        build_tool_output(tool_call, result, observation, is_final: is_final)
      rescue StandardError => e
        # Emit error event
        emit_error(e, context: { tool_name: tool_call.name, arguments: tool_call.arguments }, recoverable: true)
        build_tool_output(tool_call, nil, "Error in #{tool_call.name}: #{e.message}")
      end

      def build_tool_output(tool_call, output, observation, is_final: false)
        ToolOutput.from_call(tool_call, output:, observation:, is_final:)
      end
    end
  end
end
