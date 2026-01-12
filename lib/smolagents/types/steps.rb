module Smolagents
  ActionStep = Data.define(
    :step_number, :timing, :model_output_message, :tool_calls, :error,
    :code_action, :observations, :observations_images, :action_output, :token_usage, :is_final_answer,
    :trace_id, :parent_trace_id
  ) do
    def initialize(step_number:, timing: nil, model_output_message: nil, tool_calls: nil, error: nil,
                   code_action: nil, observations: nil, observations_images: nil, action_output: nil,
                   token_usage: nil, is_final_answer: false, trace_id: nil, parent_trace_id: nil)
      super
    end

    def to_h
      { step_number:, timing: timing&.to_h, tool_calls: tool_calls&.map(&:to_h),
        error: error.is_a?(String) ? error : error&.message, code_action:, observations:,
        observations_images: observations_images&.size, action_output:, token_usage: token_usage&.to_h,
        is_final_answer:, trace_id:, parent_trace_id:,
        reasoning_content: reasoning_content&.then { |content| content.empty? ? nil : content } }.compact
    end

    def to_messages(summary_mode: false) = [model_output_message].compact

    def reasoning_content
      extract_reasoning_from_message || extract_reasoning_from_raw
    end

    def has_reasoning?
      content = reasoning_content
      !!(content && !content.empty?)
    end

    private

    def extract_reasoning_from_message
      return unless model_output_message.respond_to?(:reasoning_content)

      model_output_message.reasoning_content
    end

    def extract_reasoning_from_raw
      return unless model_output_message.respond_to?(:raw)

      raw = model_output_message.raw
      return unless raw.is_a?(Hash)

      choices = raw["choices"] || raw[:choices]
      return unless choices.is_a?(Array) && choices.any?

      first_choice = choices.first
      message = first_choice&.dig("message") || first_choice&.dig(:message)
      return unless message.is_a?(Hash)

      message["reasoning_content"] || message[:reasoning_content] ||
        message["reasoning"] || message[:reasoning]
    end
  end

  class ActionStepBuilder
    attr_accessor :step_number, :timing, :model_output_message, :tool_calls, :error,
                  :code_action, :observations, :observations_images, :action_output, :token_usage,
                  :is_final_answer, :trace_id, :parent_trace_id

    def initialize(step_number:, trace_id: nil, parent_trace_id: nil)
      @step_number = step_number
      @timing = Timing.start_now
      @is_final_answer = false
      @observations_images = nil
      @trace_id = trace_id || generate_trace_id
      @parent_trace_id = parent_trace_id
    end

    def build
      ActionStep.new(step_number:, timing:, model_output_message:, tool_calls:, error:,
                     code_action:, observations:, observations_images:, action_output:,
                     token_usage:, is_final_answer:, trace_id:, parent_trace_id:)
    end

    private

    def generate_trace_id = SecureRandom.uuid
  end

  TaskStep = Data.define(:task, :task_images) do
    def initialize(task:, task_images: nil) = super

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
