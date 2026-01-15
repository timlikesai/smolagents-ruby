module Smolagents
  module Types
    # Immutable step representing a single action in the ReAct loop.
    #
    # ActionStep captures all information about one iteration of the agent's
    # reasoning and action cycle, including the model's output, tool calls,
    # observations, timing, and any errors that occurred.
    #
    # This is the primary building block for agent execution traces. Each action step
    # documents what the agent decided to do, what tools it called, what it observed,
    # and any errors encountered. The step tracks token usage and timing to enable
    # performance analysis and instrumentation.
    #
    # @example Creating an action step
    #   step = Types::ActionStep.new(
    #     step_number: 0,
    #     tool_calls: [Types::ToolCall.new(id: "1", name: "search", arguments: {q: "ruby"})],
    #     observations: "Found 10 results..."
    #   )
    #
    # @example Checking for reasoning content
    #   if step.has_reasoning?
    #     puts "Reasoning: #{step.reasoning_content}"
    #   end
    #
    # @example Converting to messages for context window
    #   messages = step.to_messages(summary_mode: false)
    #   # Messages include model output, observations, and errors
    #
    # @see ActionStepBuilder Mutable builder for constructing action steps
    # @see AgentMemory Container that stores action steps
    # @see ExecutionOutcome Event system for step outcomes
    ActionStep = Data.define(
      :step_number, :timing, :model_output_message, :tool_calls, :error,
      :code_action, :observations, :observations_images, :action_output, :token_usage, :is_final_answer,
      :trace_id, :parent_trace_id
    ) do
      # Creates a new ActionStep with all fields initialized.
      #
      # @param step_number [Integer] Zero-based index of this step in the agent run
      # @param timing [Timing, nil] Start and end times for this step's execution
      # @param model_output_message [ChatMessage, nil] The LLM's response message
      # @param tool_calls [Array<ToolCall>, nil] Tool calls made in this step
      # @param error [String, StandardError, nil] Any error encountered during execution
      # @param code_action [String, nil] Ruby code executed by the agent
      # @param observations [String, nil] Output from tool execution or reasoning
      # @param observations_images [Array<String>, nil] Image attachments from observations
      # @param action_output [String, nil] Final output from the action
      # @param token_usage [TokenUsage, nil] Input and output token counts
      # @param is_final_answer [Boolean] Whether this step contains the final answer
      # @param trace_id [String, nil] Unique identifier for distributed tracing
      # @param parent_trace_id [String, nil] Parent step's trace ID for context linking
      # @return [ActionStep] Initialized immutable step
      def initialize(step_number:, timing: nil, model_output_message: nil, tool_calls: nil, error: nil,
                     code_action: nil, observations: nil, observations_images: nil, action_output: nil,
                     token_usage: nil, is_final_answer: false, trace_id: nil, parent_trace_id: nil)
        super
      end

      # Converts the step to a hash for serialization.
      #
      # Includes all relevant data (omitting nil values), timing breakdown,
      # token usage, and reasoning content extraction.
      #
      # @return [Hash] Step data as a hash with keys: :step_number, :timing, :tool_calls,
      #                 :code_action, :observations, :action_output, :token_usage,
      #                 :is_final_answer, :trace_id, :parent_trace_id, :reasoning_content
      # @example
      #   step.to_h
      #   # => { step_number: 0, tool_calls: [...], observations: "...", ... }
      def to_h
        core_fields.merge(execution_fields).merge(trace_fields).compact
      end

      # Converts step to chat messages for LLM context.
      #
      # Returns messages in order:
      # 1. Assistant's model output (if present and not summary_mode)
      # 2. Observation from code/tool execution (if present)
      # 3. Error message (if present)
      #
      # Used internally by agents to rebuild conversation history without
      # exceeding context window limits. Observations include retry guidance.
      #
      # @param summary_mode [Boolean] Use condensed format (omits model output for brevity)
      # @return [Array<ChatMessage>] Messages from this step in conversation order
      # @raise [StandardError] Does not raise; gracefully handles missing data
      # @example
      #   messages = action_step.to_messages(summary_mode: true)
      #   # => [ChatMessage.tool_response("Observation: ..."), ChatMessage.tool_response("Error: ...")]
      # @see ChatMessage For message types and roles
      def to_messages(summary_mode: false)
        [
          model_output_message_for(summary_mode),
          observation_message,
          error_message_with_guidance
        ].compact
      end

      private

      # to_h field helpers
      def core_fields = { step_number:, timing: timing&.to_h, error: normalize_error(error) }

      def execution_fields
        { tool_calls: tool_calls&.map(&:to_h), code_action:, observations:,
          observations_images: observations_images&.size, action_output:, token_usage: token_usage&.to_h }
      end

      def trace_fields = { is_final_answer:, trace_id:, parent_trace_id:, reasoning_content: normalize_reasoning }

      # to_messages helpers
      def model_output_message_for(summary_mode)
        model_output_message unless summary_mode || model_output_message.nil?
      end

      def observation_message
        return if observations.nil? || observations.empty?

        ChatMessage.tool_response("Observation:\n#{observations}")
      end

      def error_message_with_guidance
        return unless error

        error_text = error.is_a?(String) ? error : error.message
        ChatMessage.tool_response(
          "Error:\n#{error_text}\nNow let's retry: take care not to repeat previous errors! " \
          "If you have retried several times, try a completely different approach."
        )
      end

      public

      # Extracts reasoning content from the model output, if available.
      #
      # Supports models with extended thinking (o1, DeepSeek) that separate
      # reasoning from final output. Checks both ChatMessage fields and
      # raw API response structures.
      #
      # @return [String, nil] Reasoning content or nil if not present
      # @example
      #   step.reasoning_content
      #   # => "Let me think through this step by step..."
      # @see ChatMessage#reasoning_content For message-level reasoning
      def reasoning_content
        extract_reasoning_from_message || extract_reasoning_from_raw
      end

      # Checks if this step contains reasoning content.
      #
      # Used to determine if the agent model supports and produced extended
      # thinking output.
      #
      # @return [Boolean] True if reasoning_content is present and non-empty
      # @example
      #   if step.reasoning?
      #     puts "Agent used extended thinking"
      #   end
      def reasoning?
        content = reasoning_content
        !!(content && !content.empty?)
      end

      private

      def normalize_error(err) = err.is_a?(String) ? err : err&.message

      def normalize_reasoning = reasoning_content&.then { it.empty? ? nil : it }

      def extract_reasoning_from_message
        return unless model_output_message.respond_to?(:reasoning_content)

        model_output_message.reasoning_content
      end

      def extract_reasoning_from_raw
        return unless model_output_message.respond_to?(:raw)

        raw = model_output_message.raw
        return unless raw.is_a?(Hash)

        # Extract first message from choices (supports both string and symbol keys)
        first_message = raw.dig("choices", 0, "message") || raw.dig(:choices, 0, :message)
        return unless first_message.is_a?(Hash)

        # Return first non-nil reasoning field (supports multiple key formats)
        first_message.values_at("reasoning_content", :reasoning_content, "reasoning", :reasoning).compact.first
      end
    end

    # Immutable step representing a task given to the agent.
    #
    # TaskStep captures the user's request along with any attached images.
    # It appears at the start of a run and may appear again if the user
    # provides follow-up tasks. Tasks are the entry points for agent execution.
    #
    # @example Creating a task step
    #   step = Types::TaskStep.new(task: "Calculate 2+2")
    #   step.to_messages  # => [ChatMessage.user("Calculate 2+2")]
    #
    # @example With image attachments
    #   step = Types::TaskStep.new(
    #     task: "Describe this image",
    #     task_images: ["/path/to/image.jpg"]
    #   )
    #
    # @see AgentMemory#add_task Creates task steps in memory
    # @see Agents#run Processes task steps to produce results
    TaskStep = Data.define(:task, :task_images) do
      # Creates a new TaskStep with the given task and optional images.
      #
      # @param task [String] The user's task or request
      # @param task_images [Array<String>, nil] Image paths or URLs to attach to task
      # @return [TaskStep] Initialized immutable step
      # @example
      #   task = TaskStep.new(task: "Find the capital of France", task_images: nil)
      def initialize(task:, task_images: nil) = super

      # Converts the task step to a hash for serialization.
      #
      # @return [Hash] Hash with :task and optional :task_images count
      # @example
      #   task_step.to_h  # => { task: "Do something", task_images: 1 }
      def to_h = { task:, task_images: task_images&.length }.compact

      # Converts task step to chat messages for LLM context.
      #
      # @param summary_mode [Boolean] Ignored for task steps (always included)
      # @return [Array<ChatMessage>] Single user message containing the task
      # @example
      #   task_step.to_messages  # => [ChatMessage.user("Do something")]
      def to_messages(summary_mode: false) = [ChatMessage.user(task, images: task_images&.any? ? task_images : nil)]
    end

    # Immutable step representing planning/reasoning output.
    #
    # PlanningStep captures the agent's planning phase, including input
    # messages that prompted planning and the resulting plan. Planning steps
    # occur at the start of execution and periodically during long runs.
    #
    # @example Creating a planning step
    #   step = Types::PlanningStep.new(
    #     model_input_messages: [ChatMessage.system("Plan the task...")],
    #     model_output_message: ChatMessage.assistant("1. Search...\n2. Analyze..."),
    #     plan: "1. Search...\n2. Analyze...",
    #     timing: Timing.new(start_time: t1, end_time: t2),
    #     token_usage: TokenUsage.new(input_tokens: 50, output_tokens: 100)
    #   )
    #
    # @see Concerns::Planning Provides planning functionality to agents
    # @see PlanContext Tracks planning state across execution
    PlanningStep = Data.define(:model_input_messages, :model_output_message, :plan, :timing, :token_usage) do
      # Converts the planning step to a hash for serialization.
      #
      # @return [Hash] Hash with :plan, :timing, and :token_usage
      # @example
      #   planning_step.to_h  # => { plan: "...", timing: {...}, token_usage: {...} }
      def to_h = { plan:, timing: timing&.to_h, token_usage: token_usage&.to_h }.compact

      # Converts planning step to chat messages for LLM context.
      #
      # @param summary_mode [Boolean] If true, omits input messages (output only)
      # @return [Array<ChatMessage>] Planning conversation messages in order
      # @example
      #   planning_step.to_messages(summary_mode: false)
      #   # => [ChatMessage.system("Plan..."), ChatMessage.assistant("1. ...")]
      def to_messages(summary_mode: false)
        (summary_mode ? [] : model_input_messages.to_a) + [model_output_message].compact
      end
    end

    # Immutable step containing the system prompt.
    #
    # SystemPromptStep wraps the system prompt and provides conversion
    # to message format. Always appears first in memory. Establishes the
    # agent's role, capabilities, and behavioral constraints.
    #
    # @example Creating a system prompt step
    #   step = Types::SystemPromptStep.new(
    #     system_prompt: "You are a helpful Ruby assistant..."
    #   )
    #
    # @see AgentMemory#system_prompt Stores the system prompt step
    # @see Agents System prompts define agent behavior
    SystemPromptStep = Data.define(:system_prompt) do
      # Converts the system prompt step to a hash for serialization.
      #
      # @return [Hash] Hash with :system_prompt key
      # @example
      #   system_step.to_h  # => { system_prompt: "You are a helpful..." }
      def to_h = { system_prompt: }

      # Converts system prompt step to chat messages for LLM context.
      #
      # @param summary_mode [Boolean] Ignored for system prompt (always included)
      # @return [Array<ChatMessage>] Single system message
      # @example
      #   system_step.to_messages  # => [ChatMessage.system("You are a helpful...")]
      def to_messages(summary_mode: false) = [ChatMessage.system(system_prompt)]
    end

    # Immutable step marking task completion with final output.
    #
    # FinalAnswerStep captures the agent's final answer. It does not
    # contribute to messages since the answer is returned directly to the user.
    # This step terminates the ReAct loop and triggers finalization.
    #
    # @example Creating a final answer step
    #   step = Types::FinalAnswerStep.new(output: "The answer is 42")
    #
    # @see FinalAnswerTool Creates this step when called
    # @see Agents#run Returns this as the terminal step
    FinalAnswerStep = Data.define(:output) do
      # Converts the final answer step to a hash for serialization.
      #
      # @return [Hash] Hash with :output key containing the final answer
      # @example
      #   final_step.to_h  # => { output: "The answer is 42" }
      def to_h = { output: }

      # Converts final answer step to chat messages for LLM context.
      #
      # Returns empty array because final answers are returned to the user,
      # not fed back to the LLM.
      #
      # @param summary_mode [Boolean] Ignored
      # @return [Array] Empty array (final answer not added to context)
      # @example
      #   final_step.to_messages  # => []
      def to_messages(summary_mode: false) = []
    end
  end
end
