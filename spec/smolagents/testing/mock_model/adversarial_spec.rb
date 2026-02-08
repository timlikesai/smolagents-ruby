RSpec.describe Smolagents::Testing::MockModelAdversarial do
  let(:model) { Smolagents::Testing::MockModel.new }
  let(:user_message) { Smolagents::Types::ChatMessage.user("test") }

  describe "#queue_malformed" do
    it "returns response without code tags" do
      model.queue_malformed("Here's what I think: the answer is 42")

      result = model.generate([user_message])

      expect(result.content).to eq("Here's what I think: the answer is 42")
      expect(result.content).not_to include("<code>")
    end

    it "returns self for chaining" do
      expect(model.queue_malformed("text")).to equal(model)
    end
  end

  describe "#queue_hallucinated_tool" do
    it "returns code block with unknown tool call" do
      model.queue_hallucinated_tool("nonexistent_tool(arg: 'value')")

      result = model.generate([user_message])

      expect(result.content).to include("<code>")
      expect(result.content).to include("nonexistent_tool")
    end

    it "returns self for chaining" do
      expect(model.queue_hallucinated_tool("fake()")).to equal(model)
    end
  end

  describe "#queue_empty_response" do
    it "returns empty content" do
      model.queue_empty_response

      result = model.generate([user_message])

      expect(result.content).to eq("")
    end

    it "returns self for chaining" do
      expect(model.queue_empty_response).to equal(model)
    end
  end

  describe "#queue_empty_final_answer" do
    it "returns code block with final_answer(answer: nil)" do
      model.queue_empty_final_answer

      result = model.generate([user_message])

      expect(result.content).to include("<code>")
      expect(result.content).to include("final_answer(answer: nil)")
    end

    it "returns self for chaining" do
      expect(model.queue_empty_final_answer).to equal(model)
    end
  end

  describe "#queue_text_only" do
    it "returns prose without code blocks" do
      model.queue_text_only("the sky is blue")

      result = model.generate([user_message])

      expect(result.content).to eq("I think the answer is: the sky is blue")
      expect(result.content).not_to include("<code>")
    end

    it "returns self for chaining" do
      expect(model.queue_text_only("test")).to equal(model)
    end
  end

  describe "adversarial sequences" do
    it "supports mixing adversarial and normal responses" do
      model.queue_malformed("bad response")
      model.queue_final_answer("42")

      r1 = model.generate([user_message])
      r2 = model.generate([user_message])

      expect(r1.content).not_to include("<code>")
      expect(r2.content).to include("final_answer")
    end
  end
end
