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
      # @return [Integer] Default maximum number of concurrent threads for tool execution.
      #   Used when executing multiple tool calls in parallel to limit resource usage.
      #   Can be overridden via the max_tool_threads parameter during agent initialization.
      DEFAULT_MAX_TOOL_THREADS = 4

      def self.included(base)
        base.include(Events::Emitter)
        base.attr_reader :max_tool_threads
      end

      # Get the template path for this executor (if any).
      #
      # Subclasses can override to provide custom prompt templates.
      #
      # @return [String, nil] Path to template directory, or nil for defaults
      def template_path = nil

      # Generate the system prompt for the model.
      #
      # Combines the base tool-calling prompt with capabilities summary.
      # Includes tool definitions, team descriptions, and custom instructions.
      #
      # @return [String] Complete system prompt for the model
      #
      # @example
      #   prompt = agent.system_prompt
      #   # => "You are a helpful AI assistant with the following tools:\n\n..."
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
      #
      # Provides a summary of available tools and their usage patterns.
      # Used to augment the system prompt with additional context.
      #
      # @return [String] Capabilities prompt addendum (may be empty)
      def capabilities_prompt
        Prompts.generate_capabilities(
          tools: @tools,
          managed_agents: @managed_agents,
          agent_type: :tool_calling
        )
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

      # Simple non-blocking thread pool for parallel tool execution.
      #
      # Spawns threads immediately without blocking, tracking only the
      # active count. Used for parallel tool call execution with a maximum
      # concurrency limit.
      #
      # @example
      #   pool = ThreadPool.new(4)
      #   threads = 3.times.map { pool.spawn { do_work } }
      #   threads.each(&:join)
      class ThreadPool
        # Create a new thread pool.
        #
        # @param max_threads [Integer] Maximum concurrent threads (informational, not enforced as blocking limit)
        def initialize(max_threads)
          @max_threads = max_threads
          @mutex = Mutex.new
          @active = 0
        end

        # Spawn a new thread to execute a block.
        #
        # Immediately spawns a thread without blocking, even if max_threads
        # is exceeded. The max_threads limit is informational only, useful
        # for monitoring but not enforced.
        #
        # @yield Block to execute in a new thread
        # @return [Thread] The spawned thread
        #
        # @example
        #   thread = pool.spawn { some_work }
        #   thread.join  # Wait for completion
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

        request_event = emit_event(Events::ToolCallRequested.create(tool_name: tool_call.name, args: tool_call.arguments))
        tool.validate_tool_arguments(tool_call.arguments)
        result = tool.call(**tool_call.arguments.transform_keys(&:to_sym))
        emit_tool_completed(request_event&.id, tool_call, result)
        build_tool_output(tool_call, result, "#{tool_call.name}: #{result}", is_final: tool_call.name == "final_answer")
      rescue StandardError => e
        emit_error(e, context: { tool_name: tool_call.name, arguments: tool_call.arguments }, recoverable: true)
        build_tool_output(tool_call, nil, "Error in #{tool_call.name}: #{e.message}")
      end

      def emit_tool_completed(request_id, tool_call, result)
        observation = "#{tool_call.name}: #{result}"
        emit_event(Events::ToolCallCompleted.create(request_id:, tool_name: tool_call.name, result:, observation:, is_final: tool_call.name == "final_answer"))
      end

      def build_tool_output(tool_call, output, observation, is_final: false)
        ToolOutput.from_call(tool_call, output:, observation:, is_final:)
      end
    end
  end
end
