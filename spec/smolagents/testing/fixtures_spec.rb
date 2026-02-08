require "smolagents"
require "smolagents/testing"

RSpec.describe Smolagents::Testing::GpuFixtures do
  describe ".unreliable_model" do
    it "creates a MockModel" do
      model = described_class.unreliable_model(responses: ["final_answer(answer: 42)"])

      expect(model).to be_a(Smolagents::Testing::MockModel)
      expect(model.model_id).to eq("fixture-unreliable")
    end

    it "queues code actions from responses" do
      # With 0% failure rate, all responses are queued as code actions
      model = described_class.unreliable_model(failure_rate: 0.0, responses: ["final_answer(answer: 42)"])
      response = model.generate([])

      expect(response.content).to include("final_answer")
    end
  end

  describe ".slow_startup_model" do
    it "fails initially then succeeds" do
      model = described_class.slow_startup_model(
        warmup_failures: 2,
        responses: ["final_answer(answer: 42)"]
      )

      expect { model.generate([]) }.to raise_error(RuntimeError, /loading/)
      expect { model.generate([]) }.to raise_error(RuntimeError, /loading/)

      response = model.generate([])
      expect(response.content).to include("final_answer")
    end
  end

  describe ".no_tool_calling_model" do
    it "queues code actions" do
      model = described_class.no_tool_calling_model(responses: ["search(query: \"test\")"])

      expect(model.model_id).to eq("fixture-no-tools")
      response = model.generate([])
      expect(response.content).to include("search")
    end
  end

  describe ".limited_context_model" do
    it "creates model with low token counts" do
      model = described_class.limited_context_model(responses: ["final_answer(answer: 42)"])

      response = model.generate([])
      expect(response.token_usage.input_tokens).to eq(10)
      expect(response.token_usage.output_tokens).to eq(5)
    end
  end

  describe ".local_gpu_model" do
    it "fails once then succeeds" do
      model = described_class.local_gpu_model(responses: ["final_answer(answer: 42)"])

      expect { model.generate([]) }.to raise_error(RuntimeError)

      response = model.generate([])
      expect(response.content).to include("final_answer")
    end
  end
end
