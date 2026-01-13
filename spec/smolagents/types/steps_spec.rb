RSpec.describe Smolagents::ActionStep do
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

  describe "#has_reasoning?" do
    it "returns true when reasoning_content is present" do
      message = instance_double(Smolagents::ChatMessage, reasoning_content: "Some reasoning")
      step = described_class.new(step_number: 1, model_output_message: message)

      expect(step.has_reasoning?).to be true
    end

    it "returns false when reasoning_content is nil" do
      step = described_class.new(step_number: 1)
      expect(step.has_reasoning?).to be false
    end

    it "returns false when reasoning_content is empty string" do
      message = instance_double(Smolagents::ChatMessage, reasoning_content: "")
      step = described_class.new(step_number: 1, model_output_message: message)

      expect(step.has_reasoning?).to be false
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
  describe "#to_h" do
    it "returns hash with task" do
      step = described_class.new(task: "Do something")
      expect(step.to_h).to eq({ task: "Do something" })
    end
  end
end

RSpec.describe Smolagents::PlanningStep do
  describe "#to_h" do
    it "returns hash with plan" do
      step = described_class.new(
        model_input_messages: [],
        model_output_message: nil,
        plan: "Step 1, Step 2",
        timing: nil,
        token_usage: nil
      )
      expect(step.to_h).to eq({ plan: "Step 1, Step 2" })
    end
  end
end
