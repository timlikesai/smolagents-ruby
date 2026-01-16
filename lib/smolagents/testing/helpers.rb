module Smolagents
  module Testing
    # Helper methods for testing smolagents.
    #
    # Include this module in your test suite to get convenient helper methods
    # for creating mock models and test fixtures.
    #
    # @example RSpec integration
    #   require "smolagents/testing"
    #
    #   RSpec.configure do |config|
    #     config.include Smolagents::Testing::Helpers
    #   end
    #
    # @example Using helpers
    #   describe "MyAgent" do
    #     it "answers questions" do
    #       model = mock_model_for_single_step("42")
    #       agent = Smolagents.agent.model { model }.build
    #       expect(agent.run("question").output).to eq("42")
    #     end
    #   end
    #
    # @see MockModel The underlying mock model class
    # @see Matchers Custom RSpec matchers for agents
    module Helpers
      # Creates a MockModel pre-configured for a single-step agent test.
      #
      # The model will return a final_answer response immediately.
      # Use for simple tests where the agent should answer in one step.
      #
      # @param answer [String] The final answer the agent should return
      # @return [MockModel] Configured model ready for use
      #
      # @example
      #   model = mock_model_for_single_step("42")
      #   agent = Smolagents.agent.model { model }.build
      #   result = agent.run("What is the answer?")
      #   expect(result.output).to eq("42")
      def mock_model_for_single_step(answer)
        MockModel.new.queue_final_answer(answer)
      end

      # Creates a MockModel pre-configured for multi-step agent tests.
      #
      # Queues each step in order. Steps can be:
      # - Strings: Treated as code actions
      # - Hashes with :code key: Code action
      # - Hashes with :tool_call key: Tool call (name, plus kwargs as arguments)
      # - Hashes with :final_answer key: Final answer
      # - Hashes with :plan key: Planning response
      #
      # @param steps [Array<String, Hash>] Steps to queue in order
      # @return [MockModel] Configured model ready for use
      #
      # @example Simple multi-step
      #   model = mock_model_for_multi_step([
      #     "search(query: 'Ruby 4.0')",
      #     { final_answer: "Ruby 4.0 was released in 2024" }
      #   ])
      #
      # @example With tool calls (for ToolAgent)
      #   model = mock_model_for_multi_step([
      #     { tool_call: "search", query: "Ruby 4.0" },
      #     { final_answer: "Found it!" }
      #   ])
      def mock_model_for_multi_step(steps) # rubocop:disable Metrics/MethodLength
        MockModel.new.tap do |model|
          steps.each do |step|
            case step
            in String => code then model.queue_code_action(code)
            in { code: } then model.queue_code_action(code) # rubocop:disable Lint/DuplicateBranch -- explicit for clarity
            in { tool_call: name, **args } then model.queue_tool_call(name, **args)
            in { final_answer: answer } then model.queue_final_answer(answer)
            in { plan: plan } then model.queue_planning_response(plan)
            else model.queue_response(step.to_s)
            end
          end
        end
      end

      # Creates a MockModel with optional block configuration.
      #
      # Useful with RSpec's let for clean test setup.
      #
      # @yield [MockModel] Optional block to configure the model
      # @return [MockModel] Configured model ready for use
      #
      # @example Basic usage
      #   let(:model) { mock_model { |m| m.queue_final_answer("42") } }
      #
      # @example Without block
      #   model = mock_model
      #   model.queue_code_action("search(query: 'test')")
      def mock_model(&block)
        MockModel.new.tap { |m| block&.call(m) }
      end

      # Creates a MockModel for testing agents with planning.
      #
      # Queues a planning response followed by a final answer.
      # Useful for testing agents that separate planning from execution.
      #
      # @param plan [String] The planning text
      # @param answer [String] The final answer
      # @return [MockModel] Configured model ready for use
      #
      # @example
      #   model = mock_model_with_planning(
      #     plan: "I will search for Ruby 4.0 release info",
      #     answer: "Ruby 4.0 was released in December 2024"
      #   )
      def mock_model_with_planning(plan:, answer:)
        MockModel.new
                 .queue_planning_response(plan)
                 .queue_final_answer(answer)
      end

      # Creates a simple double that responds with a specific response.
      #
      # For quick tests where you don't need full MockModel features.
      # Requires RSpec for double() method.
      #
      # @param response [String, ChatMessage] The response to return
      # @param tool_calls [Array<Hash>, nil] Tool calls to include in response
      # @return [Object] A double that responds to generate
      def mock_model_that_responds(response, tool_calls: nil)
        message = response.is_a?(Types::ChatMessage) ? response : build_assistant_message(response, tool_calls)
        double("Model", generate: message, model_id: "mock-model") # rubocop:disable RSpec/VerifiedDoubles -- flexible test helper
      end

      # Builds an assistant ChatMessage with optional tool calls.
      #
      # @param content [String] The message content
      # @param tool_calls [Array<Hash>, nil] Tool calls to include
      # @return [ChatMessage]
      def build_assistant_message(content, tool_calls)
        return Types::ChatMessage.assistant(content) unless tool_calls

        Types::ChatMessage.assistant(content, tool_calls: tool_calls.map { |tc| Types::ToolCall.new(**tc) })
      end

      # Creates a mock streaming model for testing streaming responses.
      #
      # @param responses [Array<String>] Responses to stream
      # @return [Object] A double that responds to generate_stream
      def mock_streaming_model(*responses)
        # rubocop:disable RSpec/VerifiedDoubles -- flexible test helper
        double("StreamingModel").tap do |m|
          allow(m).to receive(:generate_stream) { |&block|
            responses.flatten.each do |r|
              block.call(Types::ChatMessage.assistant(r))
            end
          }
        end
        # rubocop:enable RSpec/VerifiedDoubles
      end

      # Creates a spy tool for tracking tool invocations.
      #
      # Spy tools record all calls made to them for later assertion.
      #
      # @param name [String] Tool name
      # @param return_value [Object] Value to return from execute (default: "ok")
      # @return [SpyTool] A spy tool instance
      #
      # @example
      #   tool = spy_tool("search")
      #   agent = Smolagents.agent.model { model }.tools(tool).build
      #   agent.run("search for Ruby")
      #
      #   expect(tool).to be_called
      #   expect(tool.last_call[:query]).to eq("Ruby")
      def spy_tool(name, return_value: "ok")
        SpyTool.new(name, return_value:)
      end

      # Creates a mock tool with predetermined behavior.
      #
      # @param name [String] Tool name
      # @param returns [Object] Value to return from execute
      # @param raises [Exception, nil] Exception to raise when called
      # @return [Tool] A mock tool instance
      #
      # @example Returning a value
      #   tool = mock_tool("calculator", returns: 42)
      #
      # @example Raising an error
      #   tool = mock_tool("failing", raises: RuntimeError.new("oops"))
      def mock_tool(name, returns: nil, raises: nil)
        Class.new(Tools::Tool) do
          self.tool_name = name
          self.description = "Mock #{name} tool"
          self.inputs = { "input" => { "type" => "string", "description" => "Input" } }
          self.output_type = "string"
          define_method(:execute) do |**_|
            raise raises if raises

            returns
          end
        end.new
      end

      # Creates an agent configured with a mock model response.
      #
      # @param model_response [String, ChatMessage] Response to return
      # @param tools [Array<Tool>] Tools to include
      # @param agent_class [Class, nil] Custom agent class
      # @return [Agent] Configured agent
      def test_agent(model_response:, tools: [], agent_class: nil)
        agent_class&.new(model: mock_model_that_responds(model_response),
                         tools:) || Agents::Agent.new(
                           model: mock_model_that_responds(model_response), tools:
                         )
      end

      # Captures agent step callbacks during execution.
      #
      # @param agent [Agent] The agent to monitor
      # @yield Block that triggers agent execution
      # @return [Array<ActionStep>] Steps captured during execution
      #
      # @example
      #   steps = capture_agent_steps(agent) do
      #     agent.run("Do something")
      #   end
      #   expect(steps.size).to eq(3)
      def capture_agent_steps(agent)
        [].tap do |steps|
          agent.register_callback(:on_step_complete) { |_, monitor| steps << monitor }
          yield
        end
      end

      # Asserts that an agent result indicates success.
      #
      # @param result [Object] The agent run result
      def assert_agent_success(result)
        expect(result).not_to be_nil
        expect(result).to be_a(String).or be_a(Hash).or be_a(Smolagents::RunResult)
      end

      # Returns a matcher for agent errors.
      #
      # @param error_class [Class] Expected error class
      # @return [Object] RSpec error matcher
      def raise_agent_error(error_class) = raise_error(error_class)

      # Creates a temporary workspace directory for agent tests.
      #
      # @yield [String] The path to the temporary directory
      # @return [Object] The result of the block
      #
      # @example
      #   with_agent_workspace do |dir|
      #     File.write("#{dir}/test.txt", "content")
      #     agent.run("Process files in #{dir}")
      #   end
      def with_agent_workspace(&)
        Dir.mktmpdir("smolagents-test-", &)
      end
    end

    # Tool that records all calls for testing.
    #
    # SpyTool acts like a normal tool but records every invocation,
    # allowing you to assert on what was called and with what arguments.
    #
    # @example
    #   tool = SpyTool.new("search")
    #   tool.call(query: "Ruby")
    #   tool.call(query: "Python")
    #
    #   expect(tool.call_count).to eq(2)
    #   expect(tool.calls.map { |c| c[:query] }).to eq(["Ruby", "Python"])
    #
    # @see Helpers#spy_tool Convenience method for creating spy tools
    class SpyTool < Tools::Tool
      self.tool_name = "spy_tool"
      self.description = "Records all calls for testing"
      self.inputs = {}
      self.output_type = "string"

      # @!attribute [r] calls
      #   @return [Array<Hash>] All recorded calls with their arguments
      attr_reader :calls

      # Creates a new spy tool.
      #
      # @param name [String] Tool name (default: "spy_tool")
      # @param return_value [Object] Value to return from execute (default: "ok")
      def initialize(name = "spy_tool", return_value: "ok")
        super()
        self.class.tool_name = name
        @calls = []
        @return_value = return_value
      end

      # Executes the tool and records the call.
      #
      # @param kwargs [Hash] Arguments passed to the tool
      # @return [Object] The configured return_value
      def execute(**kwargs)
        @calls << kwargs
        @return_value
      end

      # Returns whether the tool was called at least once.
      #
      # @return [Boolean]
      def called? = @calls.any?

      # Returns the number of times the tool was called.
      #
      # @return [Integer]
      def call_count = @calls.size

      # Returns the arguments from the last call.
      #
      # @return [Hash, nil]
      def last_call = @calls.last

      # Clears all recorded calls.
      #
      # @return [void]
      def reset!
        @calls.clear
      end
    end

    # Test fixture factory methods.
    #
    # Provides convenience methods for creating test data objects.
    # These are useful for unit testing components that work with
    # agent types without running full agent tests.
    #
    # @example Creating fixtures
    #   message = Fixtures.chat_message(role: :user, content: "Hello")
    #   step = Fixtures.action_step(step_number: 1)
    #   call = Fixtures.tool_call(name: "search", arguments: { query: "test" })
    module Fixtures
      module_function

      # Creates a ChatMessage fixture.
      #
      # @param role [Symbol] Message role (:user, :assistant, :system)
      # @param content [String] Message content
      # @param kwargs [Hash] Additional ChatMessage attributes
      # @return [ChatMessage]
      def chat_message(role: :assistant, content: "Test message", **)
        Types::ChatMessage.new(role:, content:, **)
      end

      # Creates an ActionStep fixture.
      #
      # @param step_number [Integer] Step number
      # @param kwargs [Hash] Additional ActionStep attributes
      # @return [ActionStep]
      def action_step(step_number: 1, **kwargs)
        Types::ActionStep.new(step_number:).tap do |s|
          s.timing = Types::Timing.start_now
          kwargs.each { |k, v| s.send(:"#{k}=", v) }
        end
      end

      # Creates a ToolCall fixture.
      #
      # @param name [String] Tool name
      # @param arguments [Hash] Tool arguments
      # @param id [String] Tool call ID (auto-generated if not provided)
      # @return [ToolCall]
      def tool_call(name: "test_tool", arguments: {}, id: SecureRandom.uuid)
        Types::ToolCall.new(name:, arguments:, id:)
      end

      # Creates a TokenUsage fixture.
      #
      # @param input [Integer] Input token count
      # @param output [Integer] Output token count
      # @return [TokenUsage]
      def token_usage(input: 100, output: 50)
        Types::TokenUsage.new(input_tokens: input, output_tokens: output)
      end
    end
  end
end
