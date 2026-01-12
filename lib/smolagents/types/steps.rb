module Smolagents
  class MemoryStep
    def to_h = raise(NotImplementedError)
    def to_messages(summary_mode: false) = raise(NotImplementedError)
  end

  ActionStep = Data.define(
    :step_number, :timing, :model_output_message, :tool_calls, :error,
    :code_action, :observations, :action_output, :token_usage, :is_final_answer
  ) do
    def initialize(step_number:, timing: nil, model_output_message: nil, tool_calls: nil, error: nil,
                   code_action: nil, observations: nil, action_output: nil, token_usage: nil, is_final_answer: false)
      super
    end

    def to_h
      { step_number:, timing: timing&.to_h, tool_calls: tool_calls&.map(&:to_h),
        error: error.is_a?(String) ? error : error&.message, code_action:, observations:,
        action_output:, token_usage: token_usage&.to_h, is_final_answer: }.compact
    end

    def to_messages(summary_mode: false) = [model_output_message].compact
  end

  class ActionStepBuilder
    attr_accessor :step_number, :timing, :model_output_message, :tool_calls, :error,
                  :code_action, :observations, :action_output, :token_usage, :is_final_answer

    def initialize(step_number:)
      @step_number = step_number
      @timing = Timing.start_now
      @is_final_answer = false
    end

    def build
      ActionStep.new(step_number:, timing:, model_output_message:, tool_calls:, error:,
                     code_action:, observations:, action_output:, token_usage:, is_final_answer:)
    end
  end

  class TaskStep < MemoryStep
    attr_reader :task, :task_images

    def initialize(task:, task_images: nil) = (@task, @task_images = task, task_images)
    def to_h = { task:, task_images: task_images&.length }.compact
    def to_messages(summary_mode: false) = [ChatMessage.user(task, images: task_images&.any? ? task_images : nil)]
  end

  PlanningStep = Data.define(:model_input_messages, :model_output_message, :plan, :timing, :token_usage) do
    def to_h = { plan:, timing: timing&.to_h, token_usage: token_usage&.to_h }.compact
    def to_messages(summary_mode: false) = (summary_mode ? [] : model_input_messages.to_a) + [model_output_message].compact
  end

  SystemPromptStep = Data.define(:system_prompt) do
    def to_h = { system_prompt: }
    def to_messages(summary_mode: false) = [ChatMessage.system(system_prompt)]
  end

  FinalAnswerStep = Data.define(:output) do
    def to_h = { output: }
    def to_messages(summary_mode: false) = []
  end
end
