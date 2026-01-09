# frozen_string_literal: true

require_relative "../template_renderer"

module Smolagents
  # Agent that writes and executes Ruby code to solve tasks.
  # Uses CodeExecutor to run generated code securely.
  #
  # The agent receives a system prompt with tool descriptions in code format,
  # then generates Ruby code that calls tools to accomplish the task.
  #
  # @example Create and run code agent
  #   model = Smolagents::OpenAIModel.new(model_id: "gpt-4")
  #   tools = [WebSearchTool.new, FinalAnswerTool.new]
  #   agent = CodeAgent.new(tools: tools, model: model)
  #   result = agent.run("What is the capital of France?")
  class CodeAgent < MultiStepAgent
    # Code block tags for parsing
    CODE_BLOCK_OPENING_TAG = "```ruby"
    CODE_BLOCK_CLOSING_TAG = "```"

    # Authorized Ruby standard library modules
    DEFAULT_AUTHORIZED_IMPORTS = ["json", "uri", "net/http", "time", "date", "set", "base64"].freeze

    attr_reader :executor

    # Initialize code agent.
    #
    # @param tools [Array<Tool>] tools available to the agent
    # @param model [Model] language model to use
    # @param max_steps [Integer, nil] maximum reasoning steps (defaults to global config)
    # @param executor [CodeExecutor, nil] optional custom executor
    # @param authorized_imports [Array<String>, nil] Ruby modules allowed in code (defaults to global config)
    # @param custom_instructions [String, nil] custom instructions appended to system prompt (defaults to global config)
    # @param logger [Monitoring::AgentLogger, nil] optional logger
    def initialize(tools:, model:, max_steps: nil, executor: nil, authorized_imports: nil,
                   custom_instructions: nil, logger: nil)
      # Set instance variables BEFORE calling super (which calls system_prompt)
      config = Smolagents.configuration

      @authorized_imports = authorized_imports || config.authorized_imports
      @custom_instructions = PromptSanitizer.sanitize(
        custom_instructions || config.custom_instructions,
        logger: logger
      )

      # Load template renderer
      template_path = File.join(__dir__, "../prompts/code_agent.yaml")
      @template_renderer = TemplateRenderer.new(template_path)

      # Now call super, which will use our system_prompt method
      final_max_steps = max_steps || config.max_steps
      super(tools: tools, model: model, max_steps: final_max_steps, logger: logger)

      @executor = executor || CodeExecutor.new
      @executor.send_tools(@tools)
    end

    # Execute one reasoning step by generating and running code.
    #
    # @param task [String] current task
    # @return [ActionStep] step result with code execution output
    def step(task)
      action_step = ActionStep.new(step_number: 0)
      action_step.timing = Timing.start_now

      begin
        # Get messages for model
        messages = write_memory_to_messages

        # Generate code
        @logger.debug("Generating code", task: task)
        response = @model.generate(messages, stop_sequences: nil)

        action_step.model_output_message = response
        action_step.token_usage = response.token_usage

        # Extract code from response
        code = PatternMatching.extract_code(response.content)
        unless code
          action_step.error = "No code block found in model response"
          action_step.timing = action_step.timing.stop
          return action_step
        end

        action_step.code_action = code
        @logger.debug("Executing code", code: code[0..100])

        # Execute code
        result = @executor.execute(code, language: :ruby, timeout: 30)

        if result.success?
          action_step.observations = result.logs
          action_step.action_output = result.output
          action_step.is_final_answer = result.is_final_answer
          @logger.debug("Code executed successfully", output: result.output)
        else
          action_step.error = result.error
          action_step.observations = result.logs
          @logger.warn("Code execution failed", error: result.error)
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
        code_block_opening_tag: CODE_BLOCK_OPENING_TAG,
        code_block_closing_tag: CODE_BLOCK_CLOSING_TAG,
        authorized_imports: @authorized_imports.join(", "),
        custom_instructions: @custom_instructions,
        managed_agents: {}
      )
    end
  end
end
