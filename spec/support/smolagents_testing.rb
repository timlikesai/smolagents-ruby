module Smolagents
  module Testing
    module Helpers
      def mock_model_that_responds(response, tool_calls: nil)
        message = if response.is_a?(ChatMessage)
                    response
                  else
                    (if tool_calls
                       ChatMessage.assistant(response, tool_calls: tool_calls.map do |tc|
                         ToolCall.new(**tc)
                       end)
                     else
                       ChatMessage.assistant(response)
                     end)
                  end
        double("Model", generate: message, model_id: "mock-model")
      end

      def mock_streaming_model(*responses)
        double("StreamingModel").tap { |m| allow(m).to receive(:generate_stream) { |&block| responses.flatten.each { |r| block.call(ChatMessage.assistant(r)) } } }
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
        agent_class&.new(model: mock_model_that_responds(model_response), tools: tools) || Agents::Code.new(model: mock_model_that_responds(model_response), tools: tools)
      end

      def capture_agent_steps(agent)
        [].tap do |steps|
          agent.register_callback(:on_step_complete) { |_, monitor| steps << monitor }
          yield
        end
      end

      def assert_agent_success(result)
        (expect(result).not_to be_nil
         expect(result).to be_a(String).or be_a(Hash).or be_a(ActionOutput))
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
      def self.chat_message(role: :assistant, content: "Test message", **) = ChatMessage.new(role: role, content: content, **)

      def self.action_step(step_number: 1, **kwargs) = ActionStep.new(step_number: step_number).tap do |s|
        s.timing = Timing.start_now
        kwargs.each { |k, v| s.send("#{k}=", v) }
      end

      def self.tool_call(name: "test_tool", arguments: {}, id: SecureRandom.uuid) = ToolCall.new(name: name, arguments: arguments, id: id)
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
        failure_message { "expected tool call to #{tool_name} with #{@expected_args.inspect}, but got: #{@actual_calls.inspect}" }
      end
    end
  end
end
