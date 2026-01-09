# frozen_string_literal: true

module Smolagents
  # Testing utilities for building and testing agents.
  # Provides mocks, fixtures, and helpers for RSpec tests.
  #
  # @example RSpec configuration
  #   # spec/spec_helper.rb
  #   require 'smolagents/testing'
  #
  #   RSpec.configure do |config|
  #     config.include Smolagents::Testing::Helpers
  #   end
  #
  # @example Using in tests
  #   RSpec.describe MyAgent do
  #     let(:mock_model) { mock_model_that_responds("Result") }
  #     let(:agent) { MyAgent.new(model: mock_model, tools: [mock_tool]) }
  #
  #     it "executes successfully" do
  #       result = agent.run("Task")
  #       expect(result).to eq("Result")
  #     end
  #   end
  module Testing
    # RSpec helpers for testing agents.
    module Helpers
      # Create a mock model that returns a fixed response.
      #
      # @param response [String, ChatMessage] response to return
      # @param tool_calls [Array<Hash>, nil] optional tool calls
      # @return [Object] mock model
      #
      # @example Simple text response
      #   model = mock_model_that_responds("Hello")
      #   agent = MyAgent.new(model: model)
      #
      # @example With tool calls
      #   model = mock_model_that_responds(
      #     "Using search",
      #     tool_calls: [{ name: "search", arguments: { query: "test" } }]
      #   )
      def mock_model_that_responds(response, tool_calls: nil)
        message = if response.is_a?(ChatMessage)
                    response
                  elsif tool_calls
                    ChatMessage.assistant(
                      response,
                      tool_calls: tool_calls.map { |tc| ToolCall.new(**tc) }
                    )
                  else
                    ChatMessage.assistant(response)
                  end

        double("Model", generate: message, model_id: "mock-model")
      end

      # Create a mock model that yields streaming responses.
      #
      # @param responses [Array<String>] responses to stream
      # @return [Object] mock streaming model
      #
      # @example
      #   model = mock_streaming_model(["Step 1", "Step 2", "Done"])
      #   agent = MyAgent.new(model: model)
      def mock_streaming_model(*responses)
        double("StreamingModel").tap do |model|
          allow(model).to receive(:generate_stream) do |&block|
            responses.flatten.each { |resp| block.call(ChatMessage.assistant(resp)) }
          end
        end
      end

      # Create a mock tool with predefined behavior.
      #
      # @param name [String] tool name
      # @param returns [Object] value to return
      # @param raises [Exception, nil] exception to raise
      # @return [Tool] mock tool
      #
      # @example Successful tool
      #   tool = mock_tool("search", returns: "Results")
      #   tool.call(query: "test") # => "Results"
      #
      # @example Failing tool
      #   tool = mock_tool("search", raises: AgentToolExecutionError.new("Failed"))
      def mock_tool(name, returns: nil, raises: nil)
        Class.new(Tool) do
          self.tool_name = name
          self.description = "Mock #{name} tool"
          self.inputs = { "input" => { "type" => "string", "description" => "Input" } }
          self.output_type = "string"

          define_method(:forward) do |**_kwargs|
            raise raises if raises

            returns
          end
        end.new
      end

      # Create a spy tool that records calls.
      #
      # @param name [String] tool name
      # @return [SpyTool] tool that records all calls
      #
      # @example
      #   tool = spy_tool("search")
      #   agent.run("Find something")
      #   expect(tool.calls).to include(hash_including(query: "something"))
      def spy_tool(name)
        SpyTool.new(name)
      end

      # Build a complete test agent with mocks.
      #
      # @param model_response [String] what the model should respond
      # @param tools [Array<Tool>] tools to provide
      # @return [CodeAgent] configured test agent
      #
      # @example
      #   agent = test_agent(
      #     model_response: "final_answer('Done')",
      #     tools: [mock_tool("search", returns: "Results")]
      #   )
      def test_agent(model_response:, tools: [], agent_class: nil)
        model = mock_model_that_responds(model_response)
        agent_class ||= defined?(CodeAgent) ? CodeAgent : MultiStepAgent
        agent_class.new(model: model, tools: tools)
      end

      # Capture agent execution steps.
      #
      # @param agent [MultiStepAgent] agent to monitor
      # @return [Array<ActionStep>] captured steps
      #
      # @example
      #   steps = capture_agent_steps(agent) do
      #     agent.run("Task")
      #   end
      #   expect(steps).to have(3).items
      def capture_agent_steps(agent)
        steps = []
        agent.register_callback(:on_step_complete) { |_, monitor| steps << monitor }
        yield
        steps
      end

      # Assert an agent completed successfully.
      #
      # @param result [Object] agent result
      # @example
      #   result = agent.run("Task")
      #   assert_agent_success(result)
      def assert_agent_success(result)
        expect(result).not_to be_nil
        expect(result).to be_a(String).or be_a(Hash).or be_a(ActionOutput)
      end

      # Assert an agent raised an error.
      #
      # @param error_class [Class] expected error class
      # @example
      #   expect { agent.run("Bad task") }.to raise_agent_error(AgentExecutionError)
      def raise_agent_error(error_class)
        raise_error(error_class)
      end

      # Create a temporary agent workspace.
      #
      # @yield [dir] block with temporary directory
      # @example
      #   with_agent_workspace do |dir|
      #     agent.run("Save file", workspace: dir)
      #     expect(File.exist?(File.join(dir, "output.txt"))).to be true
      #   end
      def with_agent_workspace(&)
        Dir.mktmpdir("smolagents-test-", &)
      end
    end

    # Spy tool that records all calls for inspection.
    class SpyTool < Tool
      self.tool_name = "spy_tool"
      self.description = "Records all calls"
      self.inputs = {}
      self.output_type = "string"

      attr_reader :calls

      def initialize(name = "spy_tool", return_value: "ok")
        super()
        self.class.tool_name = name
        @calls = []
        @return_value = return_value
      end

      def forward(**kwargs)
        @calls << kwargs
        @return_value
      end

      def called?
        @calls.any?
      end

      def call_count
        @calls.size
      end

      def last_call
        @calls.last
      end

      def reset!
        @calls.clear
      end
    end

    # Fixture builder for common test data.
    module Fixtures
      # Create a sample ChatMessage.
      #
      # @param role [Symbol] message role
      # @param content [String] message content
      # @return [ChatMessage]
      def self.chat_message(role: :assistant, content: "Test message", **)
        ChatMessage.new(role: role, content: content, **)
      end

      # Create a sample ActionStep.
      #
      # @param step_number [Integer] step number
      # @return [ActionStep]
      def self.action_step(step_number: 1, **kwargs)
        ActionStep.new.tap do |step|
          step.step_number = step_number
          step.timing = Timing.start_now
          kwargs.each { |k, v| step.send("#{k}=", v) }
        end
      end

      # Create a sample ToolCall.
      #
      # @param name [String] tool name
      # @return [ToolCall]
      def self.tool_call(name: "test_tool", arguments: {}, id: SecureRandom.uuid)
        ToolCall.new(name: name, arguments: arguments, id: id)
      end

      # Create sample TokenUsage.
      #
      # @param input [Integer] input tokens
      # @param output [Integer] output tokens
      # @return [TokenUsage]
      def self.token_usage(input: 100, output: 50)
        TokenUsage.new(input_tokens: input, output_tokens: output)
      end
    end

    # RSpec matchers for agents.
    module Matchers
      # Match a successful agent run.
      RSpec::Matchers.define :complete_successfully do
        match do |agent_or_result|
          @result = if agent_or_result.respond_to?(:run)
                      agent_or_result.run(@task)
                    else
                      agent_or_result
                    end

          !@result.nil? && !@result.is_a?(Exception)
        end

        chain :with_task do |task|
          @task = task
        end

        failure_message do
          "expected agent to complete successfully but got: #{@result.inspect}"
        end
      end

      # Match tool call with specific arguments.
      RSpec::Matchers.define :call_tool do |tool_name|
        match do |actual|
          @actual_calls = actual.is_a?(SpyTool) ? actual.calls : actual
          @actual_calls.any? { |call| matches_call?(call) }
        end

        chain :with_arguments do |args|
          @expected_args = args
        end

        def matches_call?(call)
          return false unless call.is_a?(Hash)
          return true unless @expected_args

          @expected_args.all? { |k, v| call[k] == v || call[k.to_s] == v }
        end

        failure_message do
          "expected tool call to #{tool_name} with #{@expected_args.inspect}, " \
            "but got: #{@actual_calls.inspect}"
        end
      end
    end
  end
end
