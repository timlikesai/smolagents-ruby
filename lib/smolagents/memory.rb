# frozen_string_literal: true

module Smolagents
  # Base class for memory steps in agent execution.
  # Subclasses represent different types of steps in the agent's execution history.
  class MemoryStep
    # Convert step to hash representation.
    # @return [Hash]
    def to_h
      raise NotImplementedError, "#{self.class}#to_h must be implemented"
    end

    # Convert step to chat messages.
    # @param summary_mode [Boolean] whether to use summary mode
    # @return [Array<ChatMessage>]
    def to_messages(summary_mode: false)
      raise NotImplementedError, "#{self.class}#to_messages must be implemented"
    end
  end

  # Represents an action taken by the agent (tool call or code execution).
  class ActionStep < MemoryStep
    attr_accessor :step_number, :timing, :model_input_messages, :tool_calls,
                  :error, :model_output_message, :model_output, :code_action,
                  :observations, :observations_images, :action_output,
                  :token_usage, :is_final_answer

    # @param step_number [Integer] the step number
    # @param timing [Timing] timing information
    def initialize(step_number:, timing: nil)
      @step_number = step_number
      @timing = timing || Timing.start_now
      @model_input_messages = nil
      @tool_calls = nil
      @error = nil
      @model_output_message = nil
      @model_output = nil
      @code_action = nil
      @observations = nil
      @observations_images = nil
      @action_output = nil
      @token_usage = nil
      @is_final_answer = false
    end

    def to_h
      {
        step_number: step_number,
        timing: timing&.to_h,
        tool_calls: tool_calls&.map(&:to_h),
        error: error&.message,
        model_output: model_output,
        code_action: code_action,
        observations: observations,
        action_output: action_output,
        token_usage: token_usage&.to_h,
        is_final_answer: is_final_answer
      }.compact
    end

    def to_messages(summary_mode: false)
      messages = []
      messages.concat(model_input_messages) if model_input_messages && !summary_mode
      messages << model_output_message if model_output_message
      messages
    end
  end

  # Represents a task given to the agent.
  class TaskStep < MemoryStep
    attr_reader :task, :task_images

    # @param task [String] the task description
    # @param task_images [Array, nil] images associated with the task
    def initialize(task:, task_images: nil)
      @task = task
      @task_images = task_images
    end

    def to_h
      {
        task: task,
        task_images: task_images&.length
      }.compact
    end

    def to_messages(summary_mode: false)
      [ChatMessage.user(task)]
    end
  end

  # Represents a planning step where the agent creates or updates a plan.
  class PlanningStep < MemoryStep
    attr_reader :model_input_messages, :model_output_message, :plan, :timing, :token_usage

    # @param model_input_messages [Array<ChatMessage>] messages sent to model
    # @param model_output_message [ChatMessage] model's planning output
    # @param plan [String] the generated plan
    # @param timing [Timing] timing information
    # @param token_usage [TokenUsage, nil] token usage
    def initialize(model_input_messages:, model_output_message:, plan:, timing:, token_usage: nil)
      @model_input_messages = model_input_messages
      @model_output_message = model_output_message
      @plan = plan
      @timing = timing
      @token_usage = token_usage
    end

    def to_h
      {
        plan: plan,
        timing: timing&.to_h,
        token_usage: token_usage&.to_h
      }.compact
    end

    def to_messages(summary_mode: false)
      messages = []
      messages.concat(model_input_messages) unless summary_mode
      messages << model_output_message
      messages
    end
  end

  # Represents the system prompt at the start of execution.
  class SystemPromptStep < MemoryStep
    attr_reader :system_prompt

    # @param system_prompt [String] the system prompt
    def initialize(system_prompt:)
      @system_prompt = system_prompt
    end

    def to_h
      { system_prompt: system_prompt }
    end

    def to_messages(summary_mode: false)
      [ChatMessage.system(system_prompt)]
    end
  end

  # Represents the final answer from the agent.
  class FinalAnswerStep < MemoryStep
    attr_reader :output

    # @param output [Object] the final answer
    def initialize(output:)
      @output = output
    end

    def to_h
      { output: output }
    end

    def to_messages(summary_mode: false)
      []
    end
  end

  # Manages the agent's memory (conversation history and execution steps).
  class AgentMemory
    attr_reader :system_prompt, :steps

    # @param system_prompt [String] the system prompt
    def initialize(system_prompt)
      @system_prompt = SystemPromptStep.new(system_prompt: system_prompt)
      @steps = []
    end

    # Reset memory to initial state (keeps system prompt, clears steps).
    def reset
      @steps = []
    end

    # Get succinct representation of steps (without full model inputs).
    # @return [Array<Hash>]
    def get_succinct_steps
      steps.map(&:to_h)
    end

    # Get full representation of steps (including model inputs).
    # @return [Array<Hash>]
    def get_full_steps
      steps.map { |step| step.to_h.merge(full: true) }
    end

    # Convert memory to chat messages.
    # @param summary_mode [Boolean] whether to use summary mode
    # @return [Array<ChatMessage>]
    def to_messages(summary_mode: false)
      messages = system_prompt.to_messages
      steps.each do |step|
        messages.concat(step.to_messages(summary_mode: summary_mode))
      end
      messages
    end

    # Get all code actions from ActionSteps.
    # @return [String] concatenated code
    def return_full_code
      steps
        .select { |s| s.is_a?(ActionStep) && s.code_action }
        .map(&:code_action)
        .join("\n\n")
    end

    # Add a step to memory.
    # @param step [MemoryStep] the step to add
    def add_step(step)
      @steps << step
    end

    alias << add_step
  end
end
