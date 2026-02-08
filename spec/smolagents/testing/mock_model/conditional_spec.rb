RSpec.describe Smolagents::Testing::MockModelConditional do
  let(:model) { Smolagents::Testing::MockModel.new }
  let(:user_message) { Smolagents::Types::ChatMessage.user("What is 2 + 2?") }

  describe "#when_input_matches" do
    it "triggers response when pattern matches last message" do
      model.when_input_matches(/2 \+ 2/) { "final_answer(answer: 4)" }

      result = model.generate([user_message])

      expect(result.content).to include("final_answer")
      expect(result.content).to include("4")
    end

    it "falls through to FIFO queue when no match" do
      model.when_input_matches(/no_match/) { "final_answer(answer: 'nope')" }
      model.queue_response("from queue")

      result = model.generate([user_message])

      expect(result.content).to eq("from queue")
    end

    it "checks multiple conditionals in order" do
      model.when_input_matches(/What/) { "first match" }
      model.when_input_matches(/2 \+ 2/) { "second match" }

      result = model.generate([user_message])

      expect(result.content).to include("first match")
    end

    it "passes messages to block when arity is 1" do
      received_messages = nil
      model.when_input_matches(/2 \+ 2/) do |msgs|
        received_messages = msgs
        "final_answer(answer: 4)"
      end

      model.generate([user_message])

      expect(received_messages).to eq([user_message])
    end

    it "returns self for chaining" do
      result = model.when_input_matches(/test/) { "response" }

      expect(result).to equal(model)
    end

    it "wraps response in code tags" do
      model.when_input_matches(/2 \+ 2/) { "final_answer(answer: 4)" }

      result = model.generate([user_message])

      expect(result.content).to include("<code>")
    end
  end

  describe "#default_response" do
    it "is used when queue is empty and no conditional matches" do
      model.default_response("final_answer(answer: 'fallback')")

      result = model.generate([user_message])

      expect(result.content).to include("fallback")
    end

    it "is not used when queue has responses" do
      model.default_response("final_answer(answer: 'fallback')")
      model.queue_response("from queue")

      result = model.generate([user_message])

      expect(result.content).to eq("from queue")
    end

    it "is not used when a conditional matches" do
      model.when_input_matches(/2 \+ 2/) { "final_answer(answer: 'matched')" }
      model.default_response("final_answer(answer: 'fallback')")

      result = model.generate([user_message])

      expect(result.content).to include("matched")
    end

    it "returns self for chaining" do
      result = model.default_response("final_answer(answer: 'test')")

      expect(result).to equal(model)
    end

    it "can be called multiple times across generate calls" do
      model.default_response("final_answer(answer: 'default')")

      r1 = model.generate([user_message])
      r2 = model.generate([user_message])

      expect(r1.content).to include("default")
      expect(r2.content).to include("default")
    end
  end

  describe "backward compatibility" do
    it "existing queue methods work unchanged with conditionals present" do
      model.when_input_matches(/no_match/) { "conditional" }
      model.queue_response("step 1")
      model.queue_code_action("puts 'hello'")
      model.queue_final_answer("42")

      r1 = model.generate([user_message])
      r2 = model.generate([user_message])
      r3 = model.generate([user_message])

      expect(r1.content).to eq("step 1")
      expect(r2.content).to include("<code>")
      expect(r3.content).to include("final_answer")
    end
  end

  describe "#reset!" do
    it "clears conditionals" do
      model.when_input_matches(/2 \+ 2/) { "matched" }
      model.queue_response("queue")
      model.reset!
      model.queue_response("after reset")

      result = model.generate([user_message])

      expect(result.content).to eq("after reset")
    end

    it "clears default response" do
      model.default_response("default")
      model.reset!

      expect { model.generate([user_message]) }
        .to raise_error(RuntimeError, /No more queued responses/)
    end
  end
end
