RSpec.describe Smolagents::NullStep do
  let(:instance) { described_class.empty }

  it_behaves_like "a frozen type"
  it_behaves_like "a pattern matchable type"

  describe ".empty" do
    it "creates a null step for empty responses" do
      step = described_class.empty
      expect(step.reason).to eq("empty response")
      expect(step.step_number).to eq(-1)
    end
  end

  describe ".parse_error" do
    it "creates a null step with error message" do
      step = described_class.parse_error("Invalid JSON")
      expect(step.reason).to eq("Invalid JSON")
      expect(step.step_number).to eq(-1)
    end

    it "accepts step number" do
      step = described_class.parse_error("Failed", step_number: 3)
      expect(step.step_number).to eq(3)
    end
  end

  describe ".nil_output" do
    it "creates a null step for nil model output" do
      step = described_class.nil_output
      expect(step.reason).to eq("nil model output")
    end

    it "accepts step number" do
      step = described_class.nil_output(step_number: 5)
      expect(step.step_number).to eq(5)
    end
  end

  describe "#null?" do
    it "returns true" do
      expect(instance.null?).to be true
    end
  end

  describe "#final_answer?" do
    it "returns false" do
      expect(instance.final_answer?).to be false
    end
  end

  describe "#is_final_answer" do
    it "returns false" do
      expect(instance.is_final_answer).to be false
    end
  end

  describe "#tool_calls" do
    it "returns empty array" do
      expect(instance.tool_calls).to eq([])
    end
  end

  describe "#tool_calls?" do
    it "returns false" do
      expect(instance.tool_calls?).to be false
    end
  end

  describe "#model_output" do
    it "returns empty string" do
      expect(instance.model_output).to eq("")
    end
  end

  describe "#model_output_message" do
    it "returns nil" do
      expect(instance.model_output_message).to be_nil
    end
  end

  describe "#observations" do
    it "returns empty string" do
      expect(instance.observations).to eq("")
    end
  end

  describe "#observations_images" do
    it "returns nil" do
      expect(instance.observations_images).to be_nil
    end
  end

  describe "#action_output" do
    it "returns nil" do
      expect(instance.action_output).to be_nil
    end
  end

  describe "#error" do
    it "returns nil" do
      expect(instance.error).to be_nil
    end
  end

  describe "#code_action" do
    it "returns nil" do
      expect(instance.code_action).to be_nil
    end
  end

  describe "#timing" do
    it "returns nil" do
      expect(instance.timing).to be_nil
    end
  end

  describe "#token_usage" do
    it "returns nil" do
      expect(instance.token_usage).to be_nil
    end
  end

  describe "#trace_id" do
    it "returns nil" do
      expect(instance.trace_id).to be_nil
    end
  end

  describe "#parent_trace_id" do
    it "returns nil" do
      expect(instance.parent_trace_id).to be_nil
    end
  end

  describe "#reasoning_content" do
    it "returns nil" do
      expect(instance.reasoning_content).to be_nil
    end
  end

  describe "#reasoning?" do
    it "returns false" do
      expect(instance.reasoning?).to be false
    end
  end

  describe "#evaluation_observation" do
    it "returns empty string" do
      expect(instance.evaluation_observation).to eq("")
    end
  end

  describe "#to_messages" do
    it "returns empty array" do
      expect(instance.to_messages).to eq([])
    end

    it "returns empty array with options" do
      expect(instance.to_messages(summary_mode: true)).to eq([])
    end
  end

  describe "#to_h" do
    it "returns hash with null indicator and reason" do
      step = described_class.parse_error("Bad JSON", step_number: 2)
      expect(step.to_h).to eq({ null: true, reason: "Bad JSON", step_number: 2 })
    end
  end

  describe "#deconstruct_keys" do
    it "returns hash for pattern matching" do
      step = described_class.empty
      expect(step.deconstruct_keys(nil)).to include(
        null: true,
        reason: "empty response",
        step_number: -1
      )
    end
  end

  describe "pattern matching" do
    it "matches on reason" do
      step = described_class.parse_error("Network timeout")

      result = case step
               in { reason: r }
                 r
               else
                 "no match"
               end

      expect(result).to eq("Network timeout")
    end

    it "matches on null indicator" do
      step = described_class.empty

      result = case step
               in { null: true } then "is null"
               else "not null"
               end

      expect(result).to eq("is null")
    end
  end

  describe "ActionStep interface compatibility" do
    let(:null_step) { described_class.empty }
    let(:action_step) { Smolagents::ActionStep.new(step_number: 0) }

    it "responds to same methods as ActionStep" do
      common_methods = %i[
        tool_calls observations observations_images action_output error
        code_action timing token_usage trace_id parent_trace_id
        reasoning_content reasoning? to_messages to_h deconstruct_keys
      ]

      common_methods.each do |method|
        expect(null_step).to respond_to(method)
        expect(action_step).to respond_to(method)
      end
    end

    it "provides safer defaults than ActionStep (nil-safe iteration)" do
      # NullStep returns safe defaults that don't require nil checks
      expect(null_step.tool_calls).to eq([])
      expect(null_step.to_messages).to eq([])

      # ActionStep returns nil for tool_calls when not set
      expect(action_step.tool_calls).to be_nil
    end

    it "can be used with safe navigation or after nil coalescing" do
      # Verify both step types can be iterated safely without raising
      expect(null_step.tool_calls.count).to eq(0)
      expect(null_step.to_messages.count).to eq(0)
      expect((action_step.tool_calls || []).count).to eq(0)
    end
  end
end
