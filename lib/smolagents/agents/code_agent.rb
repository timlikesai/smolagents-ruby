require_relative "../template_renderer"

module Smolagents
  class CodeAgent < MultiStepAgent
    include Concerns::StepExecution

    CODE_BLOCK_OPENING_TAG = "```ruby"
    CODE_BLOCK_CLOSING_TAG = "```"
    DEFAULT_AUTHORIZED_IMPORTS = Configuration::DEFAULT_AUTHORIZED_IMPORTS

    attr_reader :executor

    def initialize(tools:, model:, max_steps: nil, executor: nil, authorized_imports: nil, custom_instructions: nil, logger: nil)
      config = Smolagents.configuration
      @authorized_imports = authorized_imports || config.authorized_imports
      @custom_instructions = PromptSanitizer.sanitize(custom_instructions || config.custom_instructions, logger: logger)
      @template_renderer = TemplateRenderer.new(File.join(__dir__, "../prompts/code_agent.yaml"))

      super(tools: tools, model: model, max_steps: max_steps || config.max_steps, logger: logger)
      @executor = executor || CodeExecutor.new
      @executor.send_tools(@tools)
    end

    def step(task, step_number: 0)
      with_step_timing(step_number: step_number) do |action_step|
        @logger.debug("Generating code", task: task)
        response = @model.generate(write_memory_to_messages, stop_sequences: nil)
        action_step.model_output_message = response
        action_step.token_usage = response.token_usage

        code = PatternMatching.extract_code(response.content)
        unless code
          action_step.error = "No code block found in model response"
          next
        end

        action_step.code_action = code
        @logger.debug("Executing code", code: code[0..100])
        @executor.send_variables(@state)
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
      end
    end

    def system_prompt
      @template_renderer.render(:system_prompt, tools: @tools, code_block_opening_tag: CODE_BLOCK_OPENING_TAG,
                                                code_block_closing_tag: CODE_BLOCK_CLOSING_TAG,
                                                authorized_imports: @authorized_imports.join(", "),
                                                custom_instructions: @custom_instructions, managed_agents: {})
    end
  end
end
