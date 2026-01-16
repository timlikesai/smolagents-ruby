# Load MockModel class
require_relative "mock_model"

module Smolagents
  module Testing
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
      def mock_model_for_multi_step(steps) # rubocop:disable Metrics/CyclomaticComplexity
        MockModel.new.tap do |model|
          steps.each do |step|
            case step
            when String
              model.queue_code_action(step)
            when Hash
              if step.key?(:code)
                model.queue_code_action(step[:code])
              elsif step.key?(:tool_call)
                name = step[:tool_call]
                args = step.except(:tool_call)
                model.queue_tool_call(name, **args)
              elsif step.key?(:final_answer)
                model.queue_final_answer(step[:final_answer])
              elsif step.key?(:plan)
                model.queue_planning_response(step[:plan])
              else
                model.queue_response(step.to_s)
              end
            end
          end
        end
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

      def mock_model_that_responds(response, tool_calls: nil)
        message = response.is_a?(ChatMessage) ? response : build_assistant_message(response, tool_calls)
        double("Model", generate: message, model_id: "mock-model") # rubocop:disable RSpec/VerifiedDoubles -- flexible test helper
      end

      def build_assistant_message(content, tool_calls)
        return ChatMessage.assistant(content) unless tool_calls

        ChatMessage.assistant(content, tool_calls: tool_calls.map { |tc| ToolCall.new(**tc) })
      end

      def mock_streaming_model(*responses)
        # rubocop:disable RSpec/VerifiedDoubles -- flexible test helper
        double("StreamingModel").tap do |m|
          allow(m).to receive(:generate_stream) { |&block|
            responses.flatten.each do |r|
              block.call(ChatMessage.assistant(r))
            end
          }
        end
        # rubocop:enable RSpec/VerifiedDoubles
      end

      def mock_tool(name, returns: nil, raises: nil)
        Class.new(Tool) do
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

      def spy_tool(name) = SpyTool.new(name)

      def test_agent(model_response:, tools: [],
                     agent_class: nil)
        agent_class&.new(model: mock_model_that_responds(model_response),
                         tools:) || Agents::Agent.new(
                           model: mock_model_that_responds(model_response), tools:
                         )
      end

      def capture_agent_steps(agent)
        [].tap do |steps|
          agent.register_callback(:on_step_complete) { |_, monitor| steps << monitor }
          yield
        end
      end

      def assert_agent_success(result)
        (expect(result).not_to be_nil
         expect(result).to be_a(String).or be_a(Hash).or be_a(Smolagents::RunResult))
      end

      def raise_agent_error(error_class) = raise_error(error_class)
      def with_agent_workspace(&) = Dir.mktmpdir("smolagents-test-", &)
    end

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

      def execute(**kwargs) = (@calls << kwargs) && @return_value
      def called? = @calls.any?
      def call_count = @calls.size
      def last_call = @calls.last
      def reset! = @calls.clear
    end

    module Fixtures
      def self.chat_message(role: :assistant, content: "Test message", **) = ChatMessage.new(role:, content:, **)

      def self.action_step(step_number: 1, **kwargs) = ActionStep.new(step_number:).tap do |s|
        s.timing = Timing.start_now
        kwargs.each { |k, v| s.send("#{k}=", v) }
      end

      def self.tool_call(name: "test_tool", arguments: {}, id: SecureRandom.uuid) = ToolCall.new(name:, arguments:, id:)
      def self.token_usage(input: 100, output: 50) = TokenUsage.new(input_tokens: input, output_tokens: output)
    end

    module Matchers
      RSpec::Matchers.define :complete_successfully do
        match do |agent_or_result|
          @result = agent_or_result.respond_to?(:run) ? agent_or_result.run(@task) : agent_or_result
          !@result.nil? && !@result.is_a?(Exception)
        end
        chain(:with_task) { |task| @task = task }
        failure_message { "expected agent to complete successfully but got: #{@result.inspect}" }
      end

      RSpec::Matchers.define :call_tool do |tool_name|
        match do |actual|
          @actual_calls = actual.is_a?(SpyTool) ? actual.calls : actual
          @actual_calls.any? do |call|
            call.is_a?(Hash) && (!@expected_args || @expected_args.all? do |k, v|
              call[k] == v || call[k.to_s] == v
            end)
          end
        end
        chain(:with_arguments) { |args| @expected_args = args }
        failure_message do
          "expected tool call to #{tool_name} with #{@expected_args.inspect}, but got: #{@actual_calls.inspect}"
        end
      end
    end
  end
end
