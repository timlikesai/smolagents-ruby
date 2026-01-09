# frozen_string_literal: true

require_relative "../template_renderer"
require "concurrent"

module Smolagents
  # Agent that uses JSON tool calling format to solve tasks.
  # More reliable than code generation for smaller models.
  #
  # The agent receives tool schemas and makes structured tool calls
  # in JSON format, which are then executed by the agent.
  #
  # Supports parallel tool execution for better performance when
  # multiple independent tools are called in a single step.
  #
  # @example Create and run tool calling agent
  #   model = Smolagents::OpenAIModel.new(model_id: "gpt-4")
  #   tools = [WebSearchTool.new, FinalAnswerTool.new]
  #   agent = ToolCallingAgent.new(tools: tools, model: model)
  #   result = agent.run("What is the capital of France?")
  #
  # @example With parallel execution
  #   agent = ToolCallingAgent.new(
  #     tools: tools,
  #     model: model,
  #     max_tool_threads: 8  # Execute up to 8 tools in parallel
  #   )
  class ToolCallingAgent < MultiStepAgent
    # Default number of threads for parallel tool execution.
    DEFAULT_MAX_TOOL_THREADS = 4

    attr_reader :max_tool_threads

    # Initialize tool calling agent.
    #
    # @param tools [Array<Tool>] tools available to the agent
    # @param model [Model] language model to use
    # @param max_steps [Integer, nil] maximum reasoning steps (defaults to global config)
    # @param max_tool_threads [Integer] maximum threads for parallel tool execution
    # @param custom_instructions [String, nil] custom instructions appended to system prompt (defaults to global config)
    # @param logger [Monitoring::AgentLogger, nil] optional logger
    def initialize(tools:, model:, max_steps: nil, max_tool_threads: DEFAULT_MAX_TOOL_THREADS,
                   custom_instructions: nil, logger: nil)
      # Set instance variables BEFORE calling super (which calls system_prompt)
      config = Smolagents.configuration

      @custom_instructions = PromptSanitizer.sanitize(
        custom_instructions || config.custom_instructions,
        logger: logger
      )

      # Load template renderer
      template_path = File.join(__dir__, "../prompts/toolcalling_agent.yaml")
      @template_renderer = TemplateRenderer.new(template_path)

      # Now call super, which will use our system_prompt method
      final_max_steps = max_steps || config.max_steps
      super(tools: tools, model: model, max_steps: final_max_steps, logger: logger)

      @max_tool_threads = max_tool_threads
      @thread_pool = Concurrent::FixedThreadPool.new(@max_tool_threads)
    end

    # Execute one reasoning step by making tool calls.
    #
    # @param task [String] current task
    # @return [ActionStep] step result with tool call outputs
    def step(task)
      action_step = ActionStep.new(step_number: 0)
      action_step.timing = Timing.start_now

      begin
        # Get messages for model
        messages = write_memory_to_messages

        # Generate with tools
        @logger.debug("Generating with tools", task: task, tool_count: @tools.size)
        response = @model.generate(messages, tools_to_call_from: @tools.values)

        action_step.model_output_message = response
        action_step.token_usage = response.token_usage

        # Check for tool calls
        if response.tool_calls && !response.tool_calls.empty?
          @logger.debug("Executing tool calls", count: response.tool_calls.size)
          tool_outputs = execute_tool_calls(response.tool_calls)

          action_step.tool_calls = response.tool_calls
          action_step.observations = format_tool_outputs(tool_outputs)

          # Check if any tool call was final_answer
          final_output = tool_outputs.find(&:is_final_answer)
          if final_output
            action_step.action_output = final_output.output
            action_step.is_final_answer = true
          end
        elsif response.content && !response.content.empty?
          # Model generated text instead of tool call
          @logger.debug("Model generated text response")
          action_step.observations = response.content
        else
          action_step.error = "Model did not generate tool calls or content"
        end
      rescue StandardError => e
        action_step.error = "#{e.class}: #{e.message}"
        @logger.error("Step error", error: e.message)
      end

      action_step.timing = action_step.timing.stop
      action_step
    end

    # Get system prompt with tool descriptions.
    #
    # @return [String] formatted system prompt
    def system_prompt
      @template_renderer.render(
        :system_prompt,
        tools: @tools,
        custom_instructions: @custom_instructions,
        managed_agents: {}
      )
    end

    private

    # Execute tool calls from model response in parallel.
    # Uses a thread pool to execute multiple tool calls concurrently.
    #
    # @param tool_calls [Array<ToolCall>] tool calls to execute
    # @return [Array<ToolOutput>] tool execution results (in original order)
    def execute_tool_calls(tool_calls)
      # For a single tool call, execute directly without overhead
      return [execute_tool_call(tool_calls.first)] if tool_calls.size == 1

      # Execute tool calls in parallel using futures
      futures = tool_calls.map do |tool_call|
        Concurrent::Future.execute(executor: @thread_pool) do
          execute_tool_call(tool_call)
        end
      end

      # Wait for all futures and collect results in order
      futures.map do |future|
        future.value(10) # 10 second timeout per tool
      end
    end

    # Execute a single tool call.
    #
    # @param tool_call [ToolCall] tool call to execute
    # @return [ToolOutput] execution result
    def execute_tool_call(tool_call)
      tool = @tools[tool_call.name]

      unless tool
        return ToolOutput.new(
          id: tool_call.id,
          output: nil,
          is_final_answer: false,
          observation: "Error: Unknown tool '#{tool_call.name}'",
          tool_call: tool_call
        )
      end

      begin
        # Validate arguments
        tool.validate_tool_arguments(tool_call.arguments)

        # Execute tool
        result = tool.call(**symbolize_keys(tool_call.arguments))

        # Check if this is final_answer
        is_final = tool_call.name == "final_answer"

        ToolOutput.new(
          id: tool_call.id,
          output: result,
          is_final_answer: is_final,
          observation: "Tool '#{tool_call.name}' returned: #{result}",
          tool_call: tool_call
        )
      rescue StandardError => e
        @logger.warn("Tool execution error", tool: tool_call.name, error: e.message)
        ToolOutput.new(
          id: tool_call.id,
          output: nil,
          is_final_answer: false,
          observation: "Error executing '#{tool_call.name}': #{e.message}",
          tool_call: tool_call
        )
      end
    end

    # Format tool outputs for observation.
    #
    # @param tool_outputs [Array<ToolOutput>] tool outputs
    # @return [String] formatted observations
    def format_tool_outputs(tool_outputs)
      tool_outputs.map(&:observation).join("\n")
    end

    # Convert hash keys to symbols.
    #
    # @param hash [Hash] hash with string keys
    # @return [Hash] hash with symbol keys
    def symbolize_keys(hash)
      hash.transform_keys(&:to_sym)
    end
  end
end
