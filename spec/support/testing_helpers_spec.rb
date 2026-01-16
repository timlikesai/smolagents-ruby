RSpec.describe Smolagents::Testing::Helpers do
  # Include the helpers module for testing
  include described_class

  describe "#mock_model_for_single_step" do
    it "creates a MockModel" do
      model = mock_model_for_single_step("answer")
      expect(model).to be_a(Smolagents::Testing::MockModel)
    end

    it "queues a final_answer response" do
      model = mock_model_for_single_step("42")
      result = model.generate([])
      expect(result.content).to include("final_answer")
      expect(result.content).to include("42")
    end

    it "has exactly one response queued" do
      model = mock_model_for_single_step("test")
      expect(model.remaining_responses).to eq(1)
    end
  end

  describe "#mock_model_for_multi_step" do
    it "handles string steps as code actions" do
      model = mock_model_for_multi_step(["puts 'hello'"])
      result = model.generate([])
      expect(result.content).to include("<code>")
      expect(result.content).to include("puts 'hello'")
    end

    it "handles :code hash steps" do
      model = mock_model_for_multi_step([{ code: "x = 1 + 2" }])
      result = model.generate([])
      expect(result.content).to include("x = 1 + 2")
    end

    it "handles :tool_call hash steps" do
      model = mock_model_for_multi_step([{ tool_call: "search", query: "Ruby" }])
      result = model.generate([])
      expect(result.tool_calls).not_to be_empty
      expect(result.tool_calls.first.name).to eq("search")
      expect(result.tool_calls.first.arguments[:query]).to eq("Ruby")
    end

    it "handles :final_answer hash steps" do
      model = mock_model_for_multi_step([{ final_answer: "done" }])
      result = model.generate([])
      expect(result.content).to include('final_answer("done")')
    end

    it "handles :plan hash steps" do
      model = mock_model_for_multi_step([{ plan: "I will search first" }])
      result = model.generate([])
      expect(result.content).to eq("I will search first")
    end

    it "queues multiple steps in order" do
      model = mock_model_for_multi_step([
                                          "search(query: 'test')",
                                          { plan: "Analyzing..." },
                                          { final_answer: "Found it" }
                                        ])

      expect(model.remaining_responses).to eq(3)

      first = model.generate([])
      expect(first.content).to include("search")

      second = model.generate([])
      expect(second.content).to eq("Analyzing...")

      third = model.generate([])
      expect(third.content).to include("final_answer")
    end
  end

  describe "#mock_model_with_planning" do
    it "queues plan then final answer" do
      model = mock_model_with_planning(
        plan: "I will search",
        answer: "Found the result"
      )

      expect(model.remaining_responses).to eq(2)

      first = model.generate([])
      expect(first.content).to eq("I will search")

      second = model.generate([])
      expect(second.content).to include("final_answer")
      expect(second.content).to include("Found the result")
    end
  end
end
