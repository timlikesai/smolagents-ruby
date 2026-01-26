RSpec.describe Smolagents::Concerns::CodeGeneration do
  before do
    stub_const("TestCodeGenerator", Class.new do
      include Smolagents::Concerns::CodeGeneration

      attr_accessor :model

      def initialize(model: nil)
        @model = model
      end

      def write_memory_to_messages
        [Smolagents::ChatMessage.user("Test task")]
      end
    end)
  end

  let(:mock_model) do
    instance_double(Smolagents::Models::Model)
  end

  let(:generator) do
    TestCodeGenerator.new(model: mock_model)
  end

  describe "#generate_code_response" do
    let(:action_step) do
      Smolagents::ActionStepBuilder.new(step_number: 0)
    end

    let(:response_message) do
      Smolagents::ChatMessage.assistant(
        "```ruby\nputs 'hello'\n```",
        tool_calls: nil,
        token_usage: Smolagents::Types::TokenUsage.new(input_tokens: 10, output_tokens: 5)
      )
    end

    before do
      allow(mock_model).to receive(:generate).and_return(response_message)
    end

    it "calls model.generate with memory messages" do
      generator.generate_code_response(action_step)

      expect(mock_model).to have_received(:generate)
        .with([Smolagents::ChatMessage.user("Test task")], stop_sequences: nil)
    end

    it "updates action_step with model_output_message" do
      generator.generate_code_response(action_step)

      expect(action_step.model_output_message).to eq(response_message)
    end

    it "updates action_step with token_usage" do
      generator.generate_code_response(action_step)

      expect(action_step.token_usage.input_tokens).to eq(10)
      expect(action_step.token_usage.output_tokens).to eq(5)
    end

    it "returns the response" do
      result = generator.generate_code_response(action_step)

      expect(result).to eq(response_message)
    end
  end
end
