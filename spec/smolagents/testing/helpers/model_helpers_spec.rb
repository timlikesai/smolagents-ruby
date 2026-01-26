RSpec.describe Smolagents::Testing::Helpers::ModelHelpers do
  include described_class

  describe "#mock_single_step" do
    it "creates a MockModel" do
      model = mock_single_step("42")

      expect(model).to be_a(Smolagents::Testing::MockModel)
    end

    it "queues a final answer" do
      model = mock_single_step("success")

      result = model.generate([])

      expect(result.content).to include("final_answer")
      expect(result.content).to include("success")
    end

    it "prepares model for single-step execution" do
      model = mock_single_step("result")

      expect(model.remaining_responses).to eq(1)
      expect(model.exhausted?).to be false
    end

    it "accepts string answer" do
      model = mock_single_step("answer text")

      result = model.generate([])

      expect(result.content).to include("answer text")
    end

    it "wraps answer in code tags" do
      model = mock_single_step("42")

      result = model.generate([])

      expect(result.content).to include("<code>")
      expect(result.content).to include("</code>")
    end
  end

  describe "#mock_model" do
    it "creates a MockModel" do
      model = mock_model

      expect(model).to be_a(Smolagents::Testing::MockModel)
    end

    it "returns unconfigured model when no block given" do
      model = mock_model

      expect(model.remaining_responses).to eq(0)
    end

    it "calls block with the model" do
      block_called = false
      received_model = nil

      mock_model do |m|
        block_called = true
        received_model = m
      end

      expect(block_called).to be true
      expect(received_model).to be_a(Smolagents::Testing::MockModel)
    end

    it "allows configuration in block" do
      model = mock_model do |m|
        m.queue_final_answer("configured")
      end

      expect(model.remaining_responses).to eq(1)
      result = model.generate([])
      expect(result.content).to include("configured")
    end

    it "allows multiple queue operations in block" do
      model = mock_model do |m|
        m.queue_response("step 1")
         .queue_response("step 2")
         .queue_final_answer("step 3")
      end

      expect(model.remaining_responses).to eq(3)
    end

    it "returns the model after block execution" do
      result = mock_model { |m| m.queue_response("test") }

      expect(result).to be_a(Smolagents::Testing::MockModel)
    end
  end

  describe "#mock_model_with_planning" do
    it "creates a MockModel" do
      model = mock_model_with_planning(plan: "step 1, step 2", answer: "final")

      expect(model).to be_a(Smolagents::Testing::MockModel)
    end

    it "queues planning response first" do
      model = mock_model_with_planning(plan: "my plan", answer: "answer")

      result = model.generate([])

      expect(result.content).to eq("my plan")
    end

    it "queues final answer second" do
      model = mock_model_with_planning(plan: "plan", answer: "answer")

      model.generate([])
      result = model.generate([])

      expect(result.content).to include("final_answer")
      expect(result.content).to include("answer")
    end

    it "has exactly two responses queued" do
      model = mock_model_with_planning(plan: "thinking...", answer: "done")

      expect(model.remaining_responses).to eq(2)
    end

    it "executes in correct order" do
      plan_text = "I will think about this"
      answer_text = "42"
      model = mock_model_with_planning(plan: plan_text, answer: answer_text)

      # First call returns plan
      result1 = model.generate([])
      expect(result1.content).to eq(plan_text)

      # Second call returns final answer
      result2 = model.generate([])
      expect(result2.content).to include(answer_text)
    end
  end

  describe "#mock_model_for_multi_step" do
    it "creates a MockModel" do
      steps = ["step 1", "step 2"]
      model = mock_model_for_multi_step(steps)

      expect(model).to be_a(Smolagents::Testing::MockModel)
    end

    it "queues multiple steps" do
      steps = ["step 1", "step 2", "step 3"]
      model = mock_model_for_multi_step(steps)

      expect(model.remaining_responses).to be > 0
    end

    it "accepts string steps" do
      steps = ["response 1", "response 2"]
      model = mock_model_for_multi_step(steps)

      result1 = model.generate([])
      result2 = model.generate([])

      expect(result1).not_to be_nil
      expect(result2).not_to be_nil
    end

    it "accepts hash steps" do
      steps = [
        { type: "response", content: "step 1" },
        { type: "code", content: "puts 'code'" }
      ]
      model = mock_model_for_multi_step(steps)

      expect(model.remaining_responses).to be > 0
    end

    it "allows mixed string and hash steps" do
      steps = [
        "simple response",
        { type: "code", content: "code" }
      ]
      model = mock_model_for_multi_step(steps)

      expect(model.remaining_responses).to be > 0
    end
  end

  describe "#mock_model_that_responds" do
    it "creates a double that responds to generate" do
      model = mock_model_that_responds("response")

      expect(model).to respond_to(:generate)
    end

    it "returns specified response" do
      response_text = "test response"
      model = mock_model_that_responds(response_text)

      result = model.generate([])

      expect(result).to be_a(Smolagents::Types::ChatMessage)
      expect(result.content).to eq(response_text)
    end

    it "accepts ChatMessage as response" do
      message = Smolagents::Types::ChatMessage.assistant("custom")
      model = mock_model_that_responds(message)

      result = model.generate([])

      expect(result).to equal(message)
    end

    it "includes tool_calls when provided" do
      tool_calls = [
        { name: "search", arguments: { query: "test" }, id: "1" }
      ]
      model = mock_model_that_responds("response", tool_calls:)

      result = model.generate([])

      expect(result.tool_calls).not_to be_empty
      expect(result.tool_calls[0].name).to eq("search")
    end

    it "creates a double (not a real model)" do
      model = mock_model_that_responds("response")

      expect(model).to be_an(Object)
      # It's a double/mock, not a real Model instance
      expect(model).not_to be_a(Smolagents::Testing::MockModel)
    end

    it "supports multiple tool calls" do
      tool_calls = [
        { name: "search", arguments: { q: "1" }, id: "1" },
        { name: "analyze", arguments: { data: "2" }, id: "2" }
      ]
      model = mock_model_that_responds("response", tool_calls:)

      result = model.generate([])

      expect(result.tool_calls.size).to eq(2)
    end

    it "has model_id attribute" do
      model = mock_model_that_responds("response")

      expect(model.model_id).to eq("mock-model")
    end
  end

  describe "#mock_streaming_model" do
    it "creates a double that responds to generate_stream" do
      model = mock_streaming_model("response 1", "response 2")

      expect(model).to respond_to(:generate_stream)
    end

    it "streams multiple responses" do
      responses = []

      model = mock_streaming_model("chunk 1", "chunk 2")
      model.generate_stream do |chunk|
        responses << chunk.content
      end

      expect(responses).to include("chunk 1", "chunk 2")
    end

    it "accepts array of responses" do
      all_responses = ["response 1", "response 2", "response 3"]

      model = mock_streaming_model(all_responses)

      responses = []
      model.generate_stream do |chunk|
        responses << chunk.content
      end

      expect(responses).to match_array(all_responses)
    end

    it "accepts variable arguments" do
      model = mock_streaming_model("chunk 1", "chunk 2", "chunk 3")

      responses = []
      model.generate_stream do |chunk|
        responses << chunk
      end

      expect(responses.size).to eq(3)
    end

    it "yields ChatMessage objects" do
      model = mock_streaming_model("response")

      model.generate_stream do |chunk|
        expect(chunk).to be_a(Smolagents::Types::ChatMessage)
        expect(chunk.role).to eq(Smolagents::Types::MessageRole::ASSISTANT)
      end
    end

    it "works with empty responses" do
      model = mock_streaming_model

      responses = []
      model.generate_stream do |chunk|
        responses << chunk
      end

      expect(responses).to be_empty
    end

    it "supports single response" do
      model = mock_streaming_model("single response")

      responses = []
      model.generate_stream do |chunk|
        responses << chunk.content
      end

      expect(responses).to eq(["single response"])
    end
  end

  describe "helper integration" do
    it "all methods are available in test context" do
      expect(self).to respond_to(:mock_single_step)
      expect(self).to respond_to(:mock_model)
      expect(self).to respond_to(:mock_model_with_planning)
      expect(self).to respond_to(:mock_model_for_multi_step)
      expect(self).to respond_to(:mock_model_that_responds)
      expect(self).to respond_to(:mock_streaming_model)
    end
  end

  describe "method chaining with mock_model" do
    it "chains multiple queue operations" do
      model = mock_model do |m|
        m.queue_response("step 1")
         .queue_response("step 2")
         .queue_final_answer("final")
      end

      expect(model.remaining_responses).to eq(3)
    end

    it "chains different queue types" do
      model = mock_model do |m|
        m.queue_planning_response("plan")
         .queue_code_action("code")
         .queue_evaluation_done("result")
      end

      expect(model.remaining_responses).to eq(3)
    end
  end

  describe "test scenario combinations" do
    it "uses single_step for simple tests" do
      model = mock_single_step("42")

      result = model.generate([])

      expect(result.content).to include("42")
      expect(model).to be_exhausted
    end

    it "uses mock_model_with_planning for planning tests" do
      model = mock_model_with_planning(
        plan: "Step 1: research, Step 2: decide",
        answer: "conclusion"
      )

      plan_response = model.generate([])
      answer_response = model.generate([])

      expect(plan_response.content).to include("research")
      expect(answer_response.content).to include("conclusion")
    end

    it "uses mock_streaming_model for streaming tests" do
      model = mock_streaming_model("streaming", "response", "chunks")

      chunks = []
      model.generate_stream { |chunk| chunks << chunk.content }

      expect(chunks.size).to eq(3)
    end
  end
end
