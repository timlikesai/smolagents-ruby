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

      # 4 responses: code action + evaluation_continue, plan, final_answer
      expect(model.remaining_responses).to eq(4)

      first = model.generate([])
      expect(first.content).to include("search")

      # Evaluation response for the code action
      eval_response = model.generate([])
      expect(eval_response.content).to include("CONTINUE")

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

  describe "#mock_model" do
    it "creates a MockModel without block" do
      model = mock_model
      expect(model).to be_a(Smolagents::Testing::MockModel)
    end

    it "creates a MockModel with block configuration" do
      model = mock_model { |m| m.queue_final_answer("configured") }
      expect(model.remaining_responses).to eq(1)
    end

    it "works well with RSpec let" do
      # Simulating how it would be used with let
      configured_model = mock_model { |m| m.queue_response("step 1").queue_final_answer("done") }
      expect(configured_model.remaining_responses).to eq(2)
    end
  end
end

RSpec.describe Smolagents::Testing::Matchers do
  include Smolagents::Testing::Helpers

  describe "be_exhausted" do
    it "matches when mock has no remaining responses" do
      model = mock_model { |m| m.queue_response("test") }
      model.generate([])
      expect(model).to be_exhausted
    end

    it "does not match when mock has remaining responses" do
      model = mock_model { |m| m.queue_response("test") }
      expect(model).not_to be_exhausted
    end
  end

  describe "have_received_calls" do
    it "matches when call count equals expected" do
      model = mock_model { |m| m.queue_response("a").queue_response("b") }
      model.generate([])
      model.generate([])
      expect(model).to have_received_calls(2)
    end

    it "does not match when call count differs" do
      model = mock_model { |m| m.queue_response("a") }
      model.generate([])
      expect(model).not_to have_received_calls(2)
    end
  end

  describe "have_seen_prompt" do
    it "matches when prompt appears in user messages" do
      model = mock_model { |m| m.queue_response("response") }
      user_msg = Smolagents::Types::ChatMessage.user("Find Ruby 4.0 release")
      model.generate([user_msg])
      expect(model).to have_seen_prompt("Ruby 4.0")
    end

    it "does not match when prompt is absent" do
      model = mock_model { |m| m.queue_response("response") }
      user_msg = Smolagents::Types::ChatMessage.user("Something else")
      model.generate([user_msg])
      expect(model).not_to have_seen_prompt("Ruby 4.0")
    end
  end

  describe "have_seen_system_prompt" do
    it "matches when system message is present" do
      model = mock_model { |m| m.queue_response("response") }
      system_msg = Smolagents::Types::ChatMessage.system("You are a helpful assistant")
      user_msg = Smolagents::Types::ChatMessage.user("Hello")
      model.generate([system_msg, user_msg])
      expect(model).to have_seen_system_prompt
    end

    it "does not match when no system message" do
      model = mock_model { |m| m.queue_response("response") }
      user_msg = Smolagents::Types::ChatMessage.user("Hello")
      model.generate([user_msg])
      expect(model).not_to have_seen_system_prompt
    end
  end
end
