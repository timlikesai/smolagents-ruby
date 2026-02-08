require "smolagents"

RSpec.describe Smolagents::Types::AgentStats do
  let(:instance) do
    described_class.new(
      steps_taken: 3, total_tokens: 500, prompt_tokens: 300, completion_tokens: 200,
      tool_calls: 5, tool_errors: 1, model_calls: 3, duration_ms: 1500, errors: 1
    )
  end
  let(:instance_a) do
    described_class.new(
      steps_taken: 2, total_tokens: 300, prompt_tokens: 200, completion_tokens: 100,
      tool_calls: 3, tool_errors: 0, model_calls: 2, duration_ms: 1000, errors: 0
    )
  end
  let(:instance_b) do
    described_class.new(
      steps_taken: 5, total_tokens: 800, prompt_tokens: 500, completion_tokens: 300,
      tool_calls: 8, tool_errors: 2, model_calls: 5, duration_ms: 2500, errors: 2
    )
  end

  it_behaves_like "a data type"
  it_behaves_like "a type with to_h",
                  expected_keys: %i[steps_taken total_tokens prompt_tokens completion_tokens
                                    tool_calls tool_errors model_calls duration_ms errors
                                    avg_tokens_per_call avg_model_duration_ms tool_error_rate]

  describe ".zero" do
    it "creates stats with all counters at zero" do
      stats = described_class.zero

      expect(stats.steps_taken).to eq(0)
      expect(stats.total_tokens).to eq(0)
      expect(stats.prompt_tokens).to eq(0)
      expect(stats.completion_tokens).to eq(0)
      expect(stats.tool_calls).to eq(0)
      expect(stats.tool_errors).to eq(0)
      expect(stats.model_calls).to eq(0)
      expect(stats.duration_ms).to eq(0)
      expect(stats.errors).to eq(0)
    end

    it "returns a frozen instance" do
      expect(described_class.zero).to be_frozen
    end
  end

  describe "#record_step" do
    it "increments steps_taken by one" do
      stats = described_class.zero.record_step
      expect(stats.steps_taken).to eq(1)
    end

    it "accumulates over multiple calls" do
      stats = described_class.zero.record_step.record_step.record_step
      expect(stats.steps_taken).to eq(3)
    end

    it "does not modify other counters" do
      stats = described_class.zero.record_step
      expect(stats.total_tokens).to eq(0)
      expect(stats.model_calls).to eq(0)
      expect(stats.tool_calls).to eq(0)
    end
  end

  describe "#record_model_call" do
    it "increments model_calls by one" do
      stats = described_class.zero.record_model_call(tokens: 100)
      expect(stats.model_calls).to eq(1)
    end

    it "accumulates token counts" do
      stats = described_class.zero.record_model_call(tokens: 150, prompt: 100, completion: 50)
      expect(stats.total_tokens).to eq(150)
      expect(stats.prompt_tokens).to eq(100)
      expect(stats.completion_tokens).to eq(50)
    end

    it "accumulates duration" do
      stats = described_class.zero
                             .record_model_call(tokens: 100, duration_ms: 200)
                             .record_model_call(tokens: 150, duration_ms: 300)
      expect(stats.duration_ms).to eq(500)
      expect(stats.model_calls).to eq(2)
      expect(stats.total_tokens).to eq(250)
    end

    it "defaults optional parameters to zero" do
      stats = described_class.zero.record_model_call
      expect(stats.total_tokens).to eq(0)
      expect(stats.prompt_tokens).to eq(0)
      expect(stats.completion_tokens).to eq(0)
      expect(stats.duration_ms).to eq(0)
      expect(stats.model_calls).to eq(1)
    end
  end

  describe "#record_tool_call" do
    it "increments tool_calls by one" do
      stats = described_class.zero.record_tool_call
      expect(stats.tool_calls).to eq(1)
      expect(stats.tool_errors).to eq(0)
    end

    it "increments tool_errors when error is true" do
      stats = described_class.zero.record_tool_call(error: true)
      expect(stats.tool_calls).to eq(1)
      expect(stats.tool_errors).to eq(1)
    end

    it "accumulates over multiple calls" do
      stats = described_class.zero
                             .record_tool_call
                             .record_tool_call(error: true)
                             .record_tool_call
      expect(stats.tool_calls).to eq(3)
      expect(stats.tool_errors).to eq(1)
    end
  end

  describe "#record_error" do
    it "increments errors by one" do
      stats = described_class.zero.record_error
      expect(stats.errors).to eq(1)
    end

    it "accumulates over multiple calls" do
      stats = described_class.zero.record_error.record_error
      expect(stats.errors).to eq(2)
    end
  end

  describe "#avg_tokens_per_call" do
    it "calculates average tokens per model call" do
      stats = described_class.zero
                             .record_model_call(tokens: 200)
                             .record_model_call(tokens: 100)
      expect(stats.avg_tokens_per_call).to eq(150.0)
    end

    it "returns 0.0 when no model calls" do
      expect(described_class.zero.avg_tokens_per_call).to eq(0.0)
    end
  end

  describe "#avg_model_duration_ms" do
    it "calculates average duration per model call" do
      stats = described_class.zero
                             .record_model_call(duration_ms: 300)
                             .record_model_call(duration_ms: 500)
      expect(stats.avg_model_duration_ms).to eq(400.0)
    end

    it "returns 0.0 when no model calls" do
      expect(described_class.zero.avg_model_duration_ms).to eq(0.0)
    end
  end

  describe "#tool_error_rate" do
    it "calculates fraction of tool calls that errored" do
      stats = described_class.zero
                             .record_tool_call
                             .record_tool_call(error: true)
                             .record_tool_call
                             .record_tool_call
      expect(stats.tool_error_rate).to eq(0.25)
    end

    it "returns 0.0 when no tool calls" do
      expect(described_class.zero.tool_error_rate).to eq(0.0)
    end
  end

  describe "#empty?" do
    it "returns true for zero stats" do
      expect(described_class.zero).to be_empty
    end

    it "returns false after recording a step" do
      expect(described_class.zero.record_step).not_to be_empty
    end

    it "returns false after recording a model call" do
      expect(described_class.zero.record_model_call).not_to be_empty
    end

    it "returns false after recording a tool call" do
      expect(described_class.zero.record_tool_call).not_to be_empty
    end

    it "returns true with only errors recorded" do
      stats = described_class.zero.record_error
      expect(stats).to be_empty
    end
  end

  describe "#to_h" do
    it "includes all base fields" do
      hash = instance.to_h

      expect(hash[:steps_taken]).to eq(3)
      expect(hash[:total_tokens]).to eq(500)
      expect(hash[:prompt_tokens]).to eq(300)
      expect(hash[:completion_tokens]).to eq(200)
      expect(hash[:tool_calls]).to eq(5)
      expect(hash[:tool_errors]).to eq(1)
      expect(hash[:model_calls]).to eq(3)
      expect(hash[:duration_ms]).to eq(1500)
      expect(hash[:errors]).to eq(1)
    end

    it "includes rounded derived metrics" do
      hash = instance.to_h

      expect(hash[:avg_tokens_per_call]).to eq(166.7)
      expect(hash[:avg_model_duration_ms]).to eq(500.0)
      expect(hash[:tool_error_rate]).to eq(0.2)
    end

    it "returns zero derived metrics for zero stats" do
      hash = described_class.zero.to_h

      expect(hash[:avg_tokens_per_call]).to eq(0.0)
      expect(hash[:avg_model_duration_ms]).to eq(0.0)
      expect(hash[:tool_error_rate]).to eq(0.0)
    end
  end

  describe "immutability" do
    it "record_step returns a new instance" do
      original = described_class.zero
      updated = original.record_step

      expect(updated).not_to equal(original)
      expect(original.steps_taken).to eq(0)
      expect(updated.steps_taken).to eq(1)
    end

    it "record_model_call returns a new instance" do
      original = described_class.zero
      updated = original.record_model_call(tokens: 100, duration_ms: 200)

      expect(updated).not_to equal(original)
      expect(original.model_calls).to eq(0)
      expect(original.total_tokens).to eq(0)
      expect(updated.model_calls).to eq(1)
      expect(updated.total_tokens).to eq(100)
    end

    it "record_tool_call returns a new instance" do
      original = described_class.zero
      updated = original.record_tool_call(error: true)

      expect(updated).not_to equal(original)
      expect(original.tool_calls).to eq(0)
      expect(original.tool_errors).to eq(0)
      expect(updated.tool_calls).to eq(1)
      expect(updated.tool_errors).to eq(1)
    end

    it "record_error returns a new instance" do
      original = described_class.zero
      updated = original.record_error

      expect(updated).not_to equal(original)
      expect(original.errors).to eq(0)
      expect(updated.errors).to eq(1)
    end

    it "all instances are frozen" do
      stats = described_class.zero
      expect(stats).to be_frozen
      expect(stats.record_step).to be_frozen
      expect(stats.record_model_call).to be_frozen
      expect(stats.record_tool_call).to be_frozen
      expect(stats.record_error).to be_frozen
    end
  end

  describe "pattern matching" do
    it "supports hash pattern matching" do
      matched = case instance
                in { steps_taken: 3, model_calls: 3 }
                  true
                else
                  false
                end

      expect(matched).to be true
    end

    it "supports guard clauses in patterns" do
      result = case instance
               in { tool_calls: tc, tool_errors: te } if tc > te
                 :more_successes
               else
                 :other
               end

      expect(result).to eq(:more_successes)
    end

    it "supports deconstruct_keys with specific keys" do
      keys = instance.deconstruct_keys(%i[steps_taken model_calls])
      expect(keys).to eq(steps_taken: 3, model_calls: 3)
    end
  end
end
