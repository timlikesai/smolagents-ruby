# frozen_string_literal: true

module Smolagents
  # Base class for memory steps in agent execution.
  class MemoryStep
    def to_h = raise(NotImplementedError, "#{self.class}#to_h must be implemented")
    def to_messages(summary_mode: false) = raise(NotImplementedError, "#{self.class}#to_messages must be implemented")
  end

  # Represents an action taken by the agent (tool call or code execution).
  class ActionStep < MemoryStep
    attr_accessor :step_number, :timing, :model_input_messages, :tool_calls,
                  :error, :model_output_message, :model_output, :code_action,
                  :observations, :observations_images, :action_output,
                  :token_usage, :is_final_answer

    def initialize(step_number:, timing: nil)
      @step_number = step_number
      @timing = timing || Timing.start_now
      @is_final_answer = false
    end

    def to_h
      {
        step_number: step_number, timing: timing&.to_h, tool_calls: tool_calls&.map(&:to_h),
        error: error&.message, model_output: model_output, code_action: code_action,
        observations: observations, action_output: action_output,
        token_usage: token_usage&.to_h, is_final_answer: is_final_answer
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

    def initialize(task:, task_images: nil)
      @task = task
      @task_images = task_images
    end

    def to_h = { task: task, task_images: task_images&.length }.compact
    def to_messages(summary_mode: false) = [ChatMessage.user(task, images: task_images&.any? ? task_images : nil)]
  end

  # Represents a planning step where the agent creates or updates a plan.
  PlanningStep = Data.define(:model_input_messages, :model_output_message, :plan, :timing, :token_usage) do
    def to_h = { plan: plan, timing: timing&.to_h, token_usage: token_usage&.to_h }.compact

    def to_messages(summary_mode: false)
      messages = []
      messages.concat(model_input_messages) unless summary_mode
      messages << model_output_message
      messages
    end
  end

  # Represents the system prompt at the start of execution.
  SystemPromptStep = Data.define(:system_prompt) do
    def to_h = { system_prompt: system_prompt }
    def to_messages(summary_mode: false) = [ChatMessage.system(system_prompt)]
  end

  # Represents the final answer from the agent.
  FinalAnswerStep = Data.define(:output) do
    def to_h = { output: output }
    def to_messages(summary_mode: false) = []
  end

  # Manages the agent's memory (conversation history and execution steps).
  class AgentMemory
    attr_reader :system_prompt, :steps

    def initialize(system_prompt)
      @system_prompt = SystemPromptStep.new(system_prompt: system_prompt)
      @steps = []
    end

    def reset = @steps = []

    def add_task(task, additional_prompting: nil, task_images: nil)
      full_task = additional_prompting ? "#{task}\n\n#{additional_prompting}" : task
      @steps << TaskStep.new(task: full_task, task_images: task_images)
    end

    def get_succinct_steps = steps.map(&:to_h)
    def get_full_steps = steps.map { |step| step.to_h.merge(full: true) }

    def to_messages(summary_mode: false)
      messages = system_prompt.to_messages
      steps.each { |step| messages.concat(step.to_messages(summary_mode: summary_mode)) }
      messages
    end

    def return_full_code
      steps.select { |s| s.is_a?(ActionStep) && s.code_action }.map(&:code_action).join("\n\n")
    end

    def add_step(step) = @steps << step
    alias << add_step
  end
end
