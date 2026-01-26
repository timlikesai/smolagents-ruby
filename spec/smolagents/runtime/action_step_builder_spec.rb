RSpec.describe Smolagents::Runtime::ActionStepBuilder do
  describe "#initialize" do
    it "creates builder with step number" do
      builder = described_class.new(step_number: 0)

      expect(builder.step_number).to eq(0)
    end

    it "initializes timing" do
      builder = described_class.new(step_number: 0)

      expect(builder.timing).to be_a(Smolagents::Types::Timing)
    end

    it "generates trace_id automatically" do
      builder = described_class.new(step_number: 0)

      expect(builder.trace_id).to be_a(String)
      expect(builder.trace_id).not_to be_empty
    end

    it "accepts custom trace_id" do
      custom_id = SecureRandom.uuid
      builder = described_class.new(step_number: 0, trace_id: custom_id)

      expect(builder.trace_id).to eq(custom_id)
    end

    it "sets parent_trace_id for hierarchical tracing" do
      parent_id = SecureRandom.uuid
      builder = described_class.new(step_number: 0, parent_trace_id: parent_id)

      expect(builder.parent_trace_id).to eq(parent_id)
    end

    it "initializes final_answer to false" do
      builder = described_class.new(step_number: 0)

      expect(builder.final_answer).to be false
    end

    it "initializes observations_images to nil" do
      builder = described_class.new(step_number: 0)

      expect(builder.observations_images).to be_nil
    end

    it "initializes other attributes to nil" do
      builder = described_class.new(step_number: 0)

      expect(builder.model_output_message).to be_nil
      expect(builder.tool_calls).to be_nil
      expect(builder.error).to be_nil
      expect(builder.code_action).to be_nil
      expect(builder.observations).to be_nil
      expect(builder.action_output).to be_nil
      expect(builder.token_usage).to be_nil
    end

    it "sets step_number to 0 for first step" do
      builder = described_class.new(step_number: 0)

      expect(builder.step_number).to eq(0)
    end

    it "sets step_number to N for Nth step" do
      builder = described_class.new(step_number: 5)

      expect(builder.step_number).to eq(5)
    end
  end

  describe "#build" do
    it "creates ActionStep with all attributes" do
      builder = described_class.new(step_number: 0)
      builder.observations = "Result: 42"
      builder.final_answer = true

      step = builder.build

      expect(step).to be_a(Smolagents::Types::ActionStep)
      expect(step.step_number).to eq(0)
      expect(step.observations).to eq("Result: 42")
      expect(step.final_answer).to be true
    end

    it "includes timing information" do
      builder = described_class.new(step_number: 0)
      step = builder.build

      expect(step.timing).to be_a(Smolagents::Types::Timing)
    end

    it "includes trace_id in step" do
      builder = described_class.new(step_number: 0)
      step = builder.build

      expect(step.trace_id).to eq(builder.trace_id)
    end

    it "includes parent_trace_id in step" do
      parent_id = SecureRandom.uuid
      builder = described_class.new(step_number: 0, parent_trace_id: parent_id)
      step = builder.build

      expect(step.parent_trace_id).to eq(parent_id)
    end

    it "captures model_output_message" do
      builder = described_class.new(step_number: 0)
      message = double("ChatMessage")
      builder.model_output_message = message

      step = builder.build

      expect(step.model_output_message).to eq(message)
    end

    it "captures tool_calls" do
      builder = described_class.new(step_number: 0)
      tool_calls = [double("ToolCall")]
      builder.tool_calls = tool_calls

      step = builder.build

      expect(step.tool_calls).to eq(tool_calls)
    end

    it "captures error" do
      builder = described_class.new(step_number: 0)
      error = StandardError.new("Test error")
      builder.error = error

      step = builder.build

      expect(step.error).to eq(error)
    end

    it "captures code_action" do
      builder = described_class.new(step_number: 0)
      code = "puts 'hello'"
      builder.code_action = code

      step = builder.build

      expect(step.code_action).to eq(code)
    end

    it "captures observations" do
      builder = described_class.new(step_number: 0)
      builder.observations = "Tool returned: success"

      step = builder.build

      expect(step.observations).to eq("Tool returned: success")
    end

    it "captures observations_images" do
      builder = described_class.new(step_number: 0)
      images = ["image1.png", "image2.png"]
      builder.observations_images = images

      step = builder.build

      expect(step.observations_images).to eq(images)
    end

    it "captures action_output" do
      builder = described_class.new(step_number: 0)
      output = { result: "success" }
      builder.action_output = output

      step = builder.build

      expect(step.action_output).to eq(output)
    end

    it "captures token_usage" do
      builder = described_class.new(step_number: 0)
      usage = Smolagents::Types::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      builder.token_usage = usage

      step = builder.build

      expect(step.token_usage).to eq(usage)
    end

    it "captures final_answer flag" do
      builder = described_class.new(step_number: 0)
      builder.final_answer = true

      step = builder.build

      expect(step.final_answer).to be true
    end

    it "returns frozen ActionStep" do
      builder = described_class.new(step_number: 0)
      step = builder.build

      expect(step).to be_frozen
    end

    it "can build multiple times with different data" do
      builder = described_class.new(step_number: 0)

      builder.observations = "First"
      step1 = builder.build

      builder.observations = "Second"
      step2 = builder.build

      expect(step1.observations).to eq("First")
      expect(step2.observations).to eq("Second")
    end
  end

  describe "attribute accessors" do
    it "allows setting and getting step_number" do
      builder = described_class.new(step_number: 0)
      builder.step_number = 5

      expect(builder.step_number).to eq(5)
    end

    it "allows setting and getting timing" do
      builder = described_class.new(step_number: 0)
      new_timing = double("Timing")
      builder.timing = new_timing

      expect(builder.timing).to eq(new_timing)
    end

    it "allows setting and getting model_output_message" do
      builder = described_class.new(step_number: 0)
      message = double("Message")
      builder.model_output_message = message

      expect(builder.model_output_message).to eq(message)
    end

    it "allows setting and getting observations" do
      builder = described_class.new(step_number: 0)
      builder.observations = "Test observation"

      expect(builder.observations).to eq("Test observation")
    end

    it "allows setting and getting final_answer" do
      builder = described_class.new(step_number: 0)
      builder.final_answer = true

      expect(builder.final_answer).to be true
    end

    it "allows setting and getting trace_id" do
      builder = described_class.new(step_number: 0)
      new_id = SecureRandom.uuid
      builder.trace_id = new_id

      expect(builder.trace_id).to eq(new_id)
    end

    it "allows setting and getting parent_trace_id" do
      builder = described_class.new(step_number: 0)
      parent_id = SecureRandom.uuid
      builder.parent_trace_id = parent_id

      expect(builder.parent_trace_id).to eq(parent_id)
    end
  end

  describe "trace_id generation" do
    it "generates unique trace_ids for different builders" do
      builder1 = described_class.new(step_number: 0)
      builder2 = described_class.new(step_number: 1)

      expect(builder1.trace_id).not_to eq(builder2.trace_id)
    end

    it "generates valid UUID format" do
      builder = described_class.new(step_number: 0)

      # UUID v4 format check
      expect(builder.trace_id).to match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i)
    end
  end

  describe "integration with ActionStep" do
    it "builds step that responds to all ActionStep methods" do
      builder = described_class.new(step_number: 3)
      builder.observations = "Test"
      builder.final_answer = true

      step = builder.build

      expect(step.respond_to?(:step_number)).to be true
      expect(step.respond_to?(:timing)).to be true
      expect(step.respond_to?(:trace_id)).to be true
    end
  end
end
