module Smolagents
  # Immutable step representing a single action in the ReAct loop.
  #
  # ActionStep captures all information about one iteration of the agent's
  # reasoning and action cycle, including the model's output, tool calls,
  # observations, timing, and any errors that occurred.
  #
  # @example Creating an action step
  #   step = ActionStep.new(
  #     step_number: 0,
  #     tool_calls: [ToolCall.new(id: "1", name: "search", arguments: {q: "ruby"})],
  #     observations: "Found 10 results..."
  #   )
  #
  # @example Checking for reasoning content
  #   if step.has_reasoning?
  #     puts "Reasoning: #{step.reasoning_content}"
  #   end
  #
  # @see ActionStepBuilder Mutable builder for constructing action steps
  # @see AgentMemory Container that stores action steps
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

    # Converts the step to a hash for serialization.
    # @return [Hash] Step data as a hash
    def to_h
      { step_number:, timing: timing&.to_h, tool_calls: tool_calls&.map(&:to_h),
        error: error.is_a?(String) ? error : error&.message, code_action:, observations:,
        observations_images: observations_images&.size, action_output:, token_usage: token_usage&.to_h,
        is_final_answer:, trace_id:, parent_trace_id:,
        reasoning_content: reasoning_content&.then { |content| content.empty? ? nil : content } }.compact
    end

    # Converts step to chat messages for LLM context.
    # @param summary_mode [Boolean] Use condensed format (ignored for ActionStep)
    # @return [Array<ChatMessage>] Messages from this step
    def to_messages(summary_mode: false) = [model_output_message].compact

    # Extracts reasoning content from the model output, if available.
    # @return [String, nil] Reasoning content or nil if not present
    def reasoning_content
      extract_reasoning_from_message || extract_reasoning_from_raw
    end

    # Checks if this step contains reasoning content.
    # @return [Boolean] True if reasoning_content is present and non-empty
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

  # Mutable builder for constructing ActionStep instances.
  #
  # ActionStepBuilder collects step data during execution and produces
  # an immutable ActionStep when complete. Automatically initializes
  # timing and generates a trace ID.
  #
  # @example Building an action step
  #   builder = ActionStepBuilder.new(step_number: 0)
  #   builder.model_output_message = model_response
  #   builder.tool_calls = parsed_calls
  #   builder.observations = "Tool returned: ..."
  #   step = builder.build
  #
  # @see ActionStep The immutable step type produced by build
  class ActionStepBuilder
    # @return [Integer] Current step number
    attr_accessor :step_number
    # @return [Timing] Execution timing tracker
    attr_accessor :timing
    # @return [ChatMessage, nil] Model's output message
    attr_accessor :model_output_message
    # @return [Array<ToolCall>, nil] Tool calls from this step
    attr_accessor :tool_calls
    # @return [Exception, String, nil] Any error that occurred
    attr_accessor :error
    # @return [String, nil] Code action (for Code agents)
    attr_accessor :code_action
    # @return [String, nil] Observations from tool execution
    attr_accessor :observations
    # @return [Array<String>, nil] Images from observations
    attr_accessor :observations_images
    # @return [Object, nil] Direct output from action
    attr_accessor :action_output
    # @return [TokenUsage, nil] Token usage for this step
    attr_accessor :token_usage
    # @return [Boolean] Whether this step contains the final answer
    attr_accessor :is_final_answer
    # @return [String] Unique trace identifier
    attr_accessor :trace_id
    # @return [String, nil] Parent trace for hierarchical tracing
    attr_accessor :parent_trace_id

    # Creates a new builder for the given step number.
    #
    # @param step_number [Integer] The step number to assign
    # @param trace_id [String, nil] Optional trace ID (auto-generated if nil)
    # @param parent_trace_id [String, nil] Optional parent trace ID
    def initialize(step_number:, trace_id: nil, parent_trace_id: nil)
      @step_number = step_number
      @timing = Timing.start_now
      @is_final_answer = false
      @observations_images = nil
      @trace_id = trace_id || generate_trace_id
      @parent_trace_id = parent_trace_id
    end

    # Builds an immutable ActionStep from the current state.
    # @return [ActionStep] The completed action step
    def build
      ActionStep.new(step_number:, timing:, model_output_message:, tool_calls:, error:,
                     code_action:, observations:, observations_images:, action_output:,
                     token_usage:, is_final_answer:, trace_id:, parent_trace_id:)
    end

    private

    def generate_trace_id = SecureRandom.uuid
  end

  # Immutable step representing a task given to the agent.
  #
  # TaskStep captures the user's request along with any attached images.
  # It appears at the start of a run and may appear again if the user
  # provides follow-up tasks.
  #
  # @example Creating a task step
  #   step = TaskStep.new(task: "Calculate 2+2")
  #   step.to_messages  # => [ChatMessage.user("Calculate 2+2")]
  #
  # @see AgentMemory#add_task Creates task steps in memory
  TaskStep = Data.define(:task, :task_images) do
    def initialize(task:, task_images: nil) = super

    # @return [Hash] Task data as hash
    def to_h = { task:, task_images: task_images&.length }.compact
    # @param summary_mode [Boolean] Ignored for task steps
    # @return [Array<ChatMessage>] User message with task
    def to_messages(summary_mode: false) = [ChatMessage.user(task, images: task_images&.any? ? task_images : nil)]
  end

  # Immutable step representing planning/reasoning output.
  #
  # PlanningStep captures the agent's planning phase, including input
  # messages that prompted planning and the resulting plan.
  #
  # @see Concerns::Planning Provides planning functionality to agents
  PlanningStep = Data.define(:model_input_messages, :model_output_message, :plan, :timing, :token_usage) do
    # @return [Hash] Planning data as hash
    def to_h = { plan:, timing: timing&.to_h, token_usage: token_usage&.to_h }.compact
    # @param summary_mode [Boolean] If true, omits input messages
    # @return [Array<ChatMessage>] Planning conversation messages
    def to_messages(summary_mode: false) = (summary_mode ? [] : model_input_messages.to_a) + [model_output_message].compact
  end

  # Immutable step containing the system prompt.
  #
  # SystemPromptStep wraps the system prompt and provides conversion
  # to message format. Always appears first in memory.
  #
  # @see AgentMemory#system_prompt Stores the system prompt step
  SystemPromptStep = Data.define(:system_prompt) do
    # @return [Hash] System prompt as hash
    def to_h = { system_prompt: }
    # @param summary_mode [Boolean] Ignored for system prompt
    # @return [Array<ChatMessage>] System message
    def to_messages(summary_mode: false) = [ChatMessage.system(system_prompt)]
  end

  # Immutable step marking task completion with final output.
  #
  # FinalAnswerStep captures the agent's final answer. It does not
  # contribute to messages since the answer is returned directly.
  #
  # @see FinalAnswerTool Creates this step when called
  FinalAnswerStep = Data.define(:output) do
    # @return [Hash] Output as hash
    def to_h = { output: }
    # @param summary_mode [Boolean] Ignored
    # @return [Array] Empty (final answer not added to messages)
    def to_messages(summary_mode: false) = []
  end
end
