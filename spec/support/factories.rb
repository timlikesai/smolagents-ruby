# Test fixture factories for smolagents.
#
# Provides convenience methods for building test objects with sensible defaults.
# Include this module via RSpec configuration for global access.
#
# @example Using factories in specs
#   RSpec.describe MyClass do
#     let(:model) { build_mock_model(responses: ["final_answer('42')"]) }
#     let(:tool) { build_test_tool(name: "search") }
#     let(:message) { build_chat_message(role: :user, content: "Hello") }
#   end
#
# @see Smolagents::Testing::MockModel The underlying mock model
# @see Smolagents::Testing::Helpers Additional testing helpers
module TestFixtures
  # Creates a MockModel with sensible defaults.
  #
  # @param responses [Array<String>] Responses to queue (wrapped in final_answer if simple strings)
  # @param overrides [Hash] Additional options
  # @option overrides [String] :model_id Custom model ID (default: "mock-model")
  # @return [Smolagents::Testing::MockModel] Configured mock model
  #
  # @example Basic usage
  #   model = build_mock_model
  #   model.queue_final_answer("42")
  #
  # @example With pre-queued responses
  #   model = build_mock_model(responses: ["search(query: 'test')", "final_answer('done')"])
  def build_mock_model(responses: [], **overrides)
    model_id = overrides.fetch(:model_id, "mock-model")
    Smolagents::Testing::MockModel.new(model_id:).tap do |model|
      responses.each do |response|
        case response
        when /^final_answer/
          model.queue_response("<code>\n#{response}\n</code>")
        when String
          model.queue_code_action(response)
        else
          model.queue_response(response.to_s)
        end
      end
    end
  end

  # Creates a minimal test tool with configurable behavior.
  #
  # @param name [String] Tool name (default: "test")
  # @param overrides [Hash] Additional options
  # @option overrides [String] :description Tool description
  # @option overrides [Hash] :inputs Input schema
  # @option overrides [String] :output_type Output type
  # @option overrides [Object] :returns Return value from execute
  # @option overrides [Exception] :raises Exception to raise from execute
  # @return [Smolagents::Tool] Configured test tool
  #
  # @example Basic test tool
  #   tool = build_test_tool(name: "calculator", returns: 42)
  #
  # @example Tool that raises
  #   tool = build_test_tool(name: "failing", raises: RuntimeError.new("oops"))
  def build_test_tool(name: "test", **overrides)
    description = overrides.fetch(:description, "Test tool for #{name}")
    inputs = overrides.fetch(:inputs, { "input" => { "type" => "string", "description" => "Input value" } })
    output_type = overrides.fetch(:output_type, "string")
    returns = overrides.fetch(:returns, "test result")
    raises = overrides[:raises]

    Class.new(Smolagents::Tool) do
      self.tool_name = name
      self.description = description
      self.inputs = inputs
      self.output_type = output_type

      define_method(:execute) do |**_|
        raise raises if raises

        returns
      end
    end.new
  end

  # Creates a test agent with sensible defaults.
  #
  # @param model [Smolagents::Models::Model, nil] Model to use (defaults to MockModel with final_answer)
  # @param tools [Array<Smolagents::Tool>, nil] Tools to include (defaults to empty)
  # @param overrides [Hash] Additional options
  # @option overrides [Integer] :max_steps Maximum steps (default: 5)
  # @option overrides [String] :name Agent name
  # @return [Smolagents::Agents::Agent] Configured test agent
  #
  # @example Basic test agent
  #   agent = build_test_agent
  #   result = agent.run("test task")
  #
  # @example With custom model and tools
  #   model = build_mock_model(responses: ["search(query: 'ruby')"])
  #   tool = build_test_tool(name: "search")
  #   agent = build_test_agent(model: model, tools: [tool])
  def build_test_agent(model: nil, tools: nil, **overrides)
    model ||= build_mock_model.tap { |m| m.queue_final_answer("test complete") }
    tools ||= []
    max_steps = overrides.fetch(:max_steps, 5)

    Smolagents::Agents::Agent.new(
      model:,
      tools:,
      max_steps:,
      **overrides.except(:max_steps)
    )
  end

  # Creates an ActionStep with sensible defaults.
  #
  # @param overrides [Hash] ActionStep attributes to override
  # @option overrides [Integer] :step_number Step number (default: 0)
  # @option overrides [Array<Smolagents::Types::ToolCall>] :tool_calls Tool calls made
  # @option overrides [String] :observations Step observations
  # @option overrides [String] :error Error message if any
  # @option overrides [String] :code_action Code that was executed
  # @option overrides [Smolagents::Types::ChatMessage] :model_output_message Model response
  # @option overrides [Boolean] :is_final_answer Whether this is the final answer
  # @return [Smolagents::Types::ActionStep] Configured action step
  #
  # @example Basic action step
  #   step = build_action_step(step_number: 1, observations: "Found 5 results")
  #
  # @example Action step with tool call
  #   step = build_action_step(
  #     tool_calls: [build_tool_call(name: "search", arguments: { query: "ruby" })]
  #   )
  def build_action_step(**overrides)
    defaults = {
      step_number: 0,
      timing: nil,
      model_output_message: nil,
      tool_calls: nil,
      error: nil,
      code_action: nil,
      observations: nil,
      observations_images: nil,
      action_output: nil,
      token_usage: nil,
      is_final_answer: false,
      trace_id: nil,
      parent_trace_id: nil
    }

    Smolagents::Types::ActionStep.new(**defaults, **overrides)
  end

  # Creates a ChatMessage with sensible defaults.
  #
  # @param role [Symbol] Message role (:user, :assistant, :system, :tool_response)
  # @param content [String] Message content (default: "test")
  # @param overrides [Hash] Additional ChatMessage attributes
  # @option overrides [Array<Smolagents::Types::ToolCall>] :tool_calls Tool calls for assistant messages
  # @option overrides [Smolagents::Types::TokenUsage] :token_usage Token usage stats
  # @option overrides [Array<String>] :images Image attachments
  # @return [Smolagents::Types::ChatMessage] Configured chat message
  #
  # @example User message
  #   msg = build_chat_message(role: :user, content: "Hello!")
  #
  # @example Assistant message with tool calls
  #   msg = build_chat_message(
  #     role: :assistant,
  #     content: "Let me search",
  #     tool_calls: [build_tool_call(name: "search")]
  #   )
  def build_chat_message(role: :user, content: "test", **overrides)
    case role
    when :system
      Smolagents::Types::ChatMessage.system(content)
    when :user
      Smolagents::Types::ChatMessage.user(content, images: overrides[:images])
    when :assistant
      Smolagents::Types::ChatMessage.assistant(
        content,
        tool_calls: overrides[:tool_calls],
        raw: overrides[:raw],
        token_usage: overrides[:token_usage],
        reasoning_content: overrides[:reasoning_content]
      )
    when :tool_response
      Smolagents::Types::ChatMessage.tool_response(content, tool_call_id: overrides[:tool_call_id])
    else
      extra_attrs = overrides.slice(:tool_calls, :raw, :token_usage, :images, :reasoning_content)
      Smolagents::Types::ChatMessage.new(role:, content:, **extra_attrs)
    end
  end

  # Creates a ToolCall with sensible defaults.
  #
  # @param name [String] Tool name (default: "test_tool")
  # @param arguments [Hash] Tool arguments (default: {})
  # @param id [String] Tool call ID (auto-generated if not provided)
  # @return [Smolagents::Types::ToolCall] Configured tool call
  #
  # @example Basic tool call
  #   call = build_tool_call(name: "search", arguments: { query: "ruby" })
  def build_tool_call(name: "test_tool", arguments: {}, id: nil)
    id ||= SecureRandom.uuid
    Smolagents::Types::ToolCall.new(name:, arguments:, id:)
  end

  # Creates a TokenUsage with sensible defaults.
  #
  # @param input_tokens [Integer] Input token count (default: 100)
  # @param output_tokens [Integer] Output token count (default: 50)
  # @return [Smolagents::Types::TokenUsage] Configured token usage
  #
  # @example Basic token usage
  #   usage = build_token_usage(input_tokens: 200, output_tokens: 100)
  def build_token_usage(input_tokens: 100, output_tokens: 50)
    Smolagents::Types::TokenUsage.new(input_tokens:, output_tokens:)
  end

  # Creates a Timing with sensible defaults.
  #
  # @param start_time [Time] Start time (default: Time.now)
  # @param end_time [Time, nil] End time (default: nil for in-progress)
  # @param duration [Float, nil] If provided, calculates end_time from start_time + duration
  # @return [Smolagents::Types::Timing] Configured timing
  #
  # @example In-progress timing
  #   timing = build_timing
  #
  # @example Completed timing with duration
  #   timing = build_timing(duration: 1.5)
  def build_timing(start_time: nil, end_time: nil, duration: nil)
    start_time ||= Time.now
    end_time ||= duration ? start_time + duration : nil
    Smolagents::Types::Timing.new(start_time:, end_time:)
  end

  # Creates a RunResult with sensible defaults.
  #
  # @param output [Object] Run output (default: "success")
  # @param state [Symbol] Run state (default: :success)
  # @param steps [Array] Steps taken (default: [])
  # @param overrides [Hash] Additional RunResult attributes
  # @return [Smolagents::Types::RunResult] Configured run result
  #
  # @example Successful result
  #   result = build_run_result(output: "42", state: :success)
  #
  # @example Failed result
  #   result = build_run_result(output: nil, state: :failure)
  def build_run_result(output: "success", state: :success, steps: [], **overrides)
    Smolagents::Types::RunResult.new(
      output:,
      state:,
      steps:,
      token_usage: overrides[:token_usage],
      timing: overrides[:timing]
    )
  end
end
