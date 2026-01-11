# frozen_string_literal: true

require_relative "../template_renderer"

module Smolagents
  # Agent that uses JSON tool calling format to solve tasks.
  # More reliable than code generation for smaller models.
  class ToolCallingAgent < MultiStepAgent
    include StepExecution

    DEFAULT_MAX_TOOL_THREADS = 4
    attr_reader :max_tool_threads

    def initialize(tools:, model:, max_steps: nil, max_tool_threads: DEFAULT_MAX_TOOL_THREADS, custom_instructions: nil, logger: nil)
      config = Smolagents.configuration
      @custom_instructions = PromptSanitizer.sanitize(custom_instructions || config.custom_instructions, logger: logger)
      @template_renderer = TemplateRenderer.new(File.join(__dir__, "../prompts/toolcalling_agent.yaml"))

      super(tools: tools, model: model, max_steps: max_steps || config.max_steps, logger: logger)
      @max_tool_threads = max_tool_threads
    end

    def step(task, step_number: 0)
      with_step_timing(step_number: step_number) do |action_step|
        @logger.debug("Generating with tools", task: task, tool_count: @tools.size)
        response = @model.generate(write_memory_to_messages, tools_to_call_from: @tools.values)
        action_step.model_output_message = response
        action_step.token_usage = response.token_usage

        if response.tool_calls&.any?
          @logger.debug("Executing tool calls", count: response.tool_calls.size)
          tool_outputs = execute_tool_calls(response.tool_calls)
          action_step.tool_calls = response.tool_calls
          action_step.observations = tool_outputs.map(&:observation).join("\n")

          if (final = tool_outputs.find(&:is_final_answer))
            action_step.action_output = final.output
            action_step.is_final_answer = true
          end
        elsif response.content&.present? || response.content&.length&.positive?
          action_step.observations = response.content
        else
          action_step.error = "Model did not generate tool calls or content"
        end
      end
    end

    def system_prompt
      @template_renderer.render(:system_prompt, tools: @tools, custom_instructions: @custom_instructions, managed_agents: {})
    end

    private

    # Execute tool calls in parallel using native Ruby threads.
    # Uses a semaphore to limit concurrency to max_tool_threads.
    # Threads are ideal for I/O-bound operations (API calls) since
    # Ruby's GVL is released during I/O operations.
    def execute_tool_calls(tool_calls)
      return [execute_tool_call(tool_calls.first)] if tool_calls.size == 1

      semaphore = Mutex.new
      results = Array.new(tool_calls.size)
      active_threads = Queue.new

      # Limit concurrency with a simple counter
      thread_count = Mutex.new
      current_threads = 0

      threads = tool_calls.each_with_index.map do |tc, index|
        # Wait if we've hit max threads
        loop do
          thread_count.synchronize do
            if current_threads < @max_tool_threads
              current_threads += 1
              break
            end
          end
          sleep(0.01)
        end

        Thread.new(tc, index) do |tool_call, idx|
          begin
            result = execute_tool_call(tool_call)
            semaphore.synchronize { results[idx] = result }
          ensure
            thread_count.synchronize { current_threads -= 1 }
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
