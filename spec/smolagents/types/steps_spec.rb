RSpec.describe Smolagents::ActionStep do
  let(:instance) { described_class.new(step_number: 1) }

  it_behaves_like "a frozen type"
  it_behaves_like "a pattern matchable type"

  describe "#reasoning_content" do
    it "returns nil when model_output_message is nil" do
      step = described_class.new(step_number: 1)
      expect(step.reasoning_content).to be_nil
    end

    it "extracts reasoning_content from message if available" do
      message = instance_double(Smolagents::ChatMessage, reasoning_content: "Let me think about this...")
      step = described_class.new(step_number: 1, model_output_message: message)

      expect(step.reasoning_content).to eq("Let me think about this...")
    end

    it "returns nil when message has no reasoning_content method" do
      message = instance_double(Smolagents::ChatMessage)
      allow(message).to receive(:respond_to?).with(:reasoning_content).and_return(false)
      allow(message).to receive(:respond_to?).with(:raw).and_return(false)
      step = described_class.new(step_number: 1, model_output_message: message)

      expect(step.reasoning_content).to be_nil
    end

    context "with raw response" do
      it "extracts reasoning_content from raw choices (string keys)" do
        message = instance_double(Smolagents::ChatMessage)
        allow(message).to receive(:respond_to?).with(:reasoning_content).and_return(false)
        allow(message).to receive(:respond_to?).with(:raw).and_return(true)
        allow(message).to receive(:raw).and_return({
                                                     "choices" => [
                                                       { "message" => { "reasoning_content" => "Deep reasoning here" } }
                                                     ]
                                                   })

        step = described_class.new(step_number: 1, model_output_message: message)
        expect(step.reasoning_content).to eq("Deep reasoning here")
      end

      it "extracts reasoning_content from raw choices (symbol keys)" do
        message = instance_double(Smolagents::ChatMessage)
        allow(message).to receive(:respond_to?).with(:reasoning_content).and_return(false)
        allow(message).to receive(:respond_to?).with(:raw).and_return(true)
        allow(message).to receive(:raw).and_return({
                                                     choices: [
                                                       { message: { reasoning_content: "Symbol key reasoning" } }
                                                     ]
                                                   })

        step = described_class.new(step_number: 1, model_output_message: message)
        expect(step.reasoning_content).to eq("Symbol key reasoning")
      end

      it "extracts reasoning from raw choices (alternative key)" do
        message = instance_double(Smolagents::ChatMessage)
        allow(message).to receive(:respond_to?).with(:reasoning_content).and_return(false)
        allow(message).to receive(:respond_to?).with(:raw).and_return(true)
        allow(message).to receive(:raw).and_return({
                                                     "choices" => [
                                                       { "message" => { "reasoning" => "Alternative reasoning key" } }
                                                     ]
                                                   })

        step = described_class.new(step_number: 1, model_output_message: message)
        expect(step.reasoning_content).to eq("Alternative reasoning key")
      end

      it "returns nil for raw without choices" do
        message = instance_double(Smolagents::ChatMessage)
        allow(message).to receive(:respond_to?).with(:reasoning_content).and_return(false)
        allow(message).to receive(:respond_to?).with(:raw).and_return(true)
        allow(message).to receive(:raw).and_return({ "model" => "test" })

        step = described_class.new(step_number: 1, model_output_message: message)
        expect(step.reasoning_content).to be_nil
      end

      it "returns nil for empty choices" do
        message = instance_double(Smolagents::ChatMessage)
        allow(message).to receive(:respond_to?).with(:reasoning_content).and_return(false)
        allow(message).to receive(:respond_to?).with(:raw).and_return(true)
        allow(message).to receive(:raw).and_return({ "choices" => [] })

        step = described_class.new(step_number: 1, model_output_message: message)
        expect(step.reasoning_content).to be_nil
      end
    end
  end

  describe "#reasoning?" do
    it "returns true when reasoning_content is present" do
      message = instance_double(Smolagents::ChatMessage, reasoning_content: "Some reasoning")
      step = described_class.new(step_number: 1, model_output_message: message)

      expect(step.reasoning?).to be true
    end

    it "returns false when reasoning_content is nil" do
      step = described_class.new(step_number: 1)
      expect(step.reasoning?).to be false
    end

    it "returns false when reasoning_content is empty string" do
      message = instance_double(Smolagents::ChatMessage, reasoning_content: "")
      step = described_class.new(step_number: 1, model_output_message: message)

      expect(step.reasoning?).to be false
    end
  end

  describe "#to_h" do
    it "includes reasoning_content when present" do
      message = instance_double(Smolagents::ChatMessage, reasoning_content: "Reasoning here")
      step = described_class.new(step_number: 1, model_output_message: message)

      expect(step.to_h[:reasoning_content]).to eq("Reasoning here")
    end

    it "excludes reasoning_content when nil" do
      step = described_class.new(step_number: 1)
      expect(step.to_h.keys).not_to include(:reasoning_content)
    end

    it "excludes reasoning_content when empty" do
      message = instance_double(Smolagents::ChatMessage, reasoning_content: "")
      step = described_class.new(step_number: 1, model_output_message: message)

      expect(step.to_h.keys).not_to include(:reasoning_content)
    end
  end
end

RSpec.describe Smolagents::ActionStepBuilder do
  describe "#build" do
    it "creates ActionStep with trace_id" do
      builder = described_class.new(step_number: 1)
      step = builder.build

      expect(step.trace_id).to match(/\A[0-9a-f-]+\z/)
    end

    it "uses provided trace_id" do
      builder = described_class.new(step_number: 1, trace_id: "custom-trace")
      step = builder.build

      expect(step.trace_id).to eq("custom-trace")
    end

    it "preserves parent_trace_id" do
      builder = described_class.new(step_number: 1, parent_trace_id: "parent-123")
      step = builder.build

      expect(step.parent_trace_id).to eq("parent-123")
    end
  end
end

RSpec.describe Smolagents::TaskStep do
  let(:step) { described_class.new(task: "Do something") }
  let(:instance) { step }

  it_behaves_like "a step type", message_count: 1

  describe "#to_h" do
    it "returns hash with task" do
      expect(step.to_h).to eq({ task: "Do something" })
    end
  end

  describe "#to_messages" do
    it "creates user message with task content" do
      messages = step.to_messages
      expect(messages.first.role).to eq(:user)
      expect(messages.first.content).to eq("Do something")
    end
  end
end

RSpec.describe Smolagents::PlanningStep do
  let(:step) do
    described_class.new(
      model_input_messages: [Smolagents::ChatMessage.system("Plan the task")],
      model_output_message: Smolagents::ChatMessage.assistant("1. Search\n2. Summarize"),
      plan: "Step 1, Step 2",
      timing: nil,
      token_usage: nil
    )
  end
  let(:instance) { step }

  it_behaves_like "a step type"

  describe "#to_h" do
    it "returns hash with plan" do
      expect(step.to_h).to eq({ plan: "Step 1, Step 2" })
    end
  end

  describe "#to_messages" do
    it "returns input and output messages by default" do
      messages = step.to_messages(summary_mode: false)
      expect(messages.size).to eq(2)
      expect(messages.first.role).to eq(:system)
      expect(messages.last.role).to eq(:assistant)
    end

    it "omits input messages in summary mode" do
      messages = step.to_messages(summary_mode: true)
      expect(messages.size).to eq(1)
      expect(messages.first.role).to eq(:assistant)
    end
  end
end
