RSpec.describe Smolagents::Testing::MockModel do
  let(:model) { described_class.new }
  let(:user_message) do
    Smolagents::Types::ChatMessage.user("What is 2 + 2?")
  end

  describe "initialization" do
    it "creates a model with default model_id" do
      model = described_class.new

      expect(model.model_id).to eq("mock-model")
    end

    it "creates a model with custom model_id" do
      model = described_class.new(model_id: "custom-mock")

      expect(model.model_id).to eq("custom-mock")
    end

    it "initializes with empty calls and responses" do
      model = described_class.new

      expect(model.calls).to eq([])
      expect(model.call_count).to eq(0)
    end
  end

  describe "#generate" do
    it "returns a queued response" do
      model.queue_response("42")

      result = model.generate([user_message])

      expect(result.role).to eq(Smolagents::Types::MessageRole::ASSISTANT)
      expect(result.content).to eq("42")
    end

    it "increments call_count" do
      model.queue_response("response 1")
      model.queue_response("response 2")

      expect { model.generate([user_message]) }.to change(model, :call_count).from(0).to(1)
      expect { model.generate([user_message]) }.to change(model, :call_count).from(1).to(2)
    end

    it "records the call" do
      model.queue_response("response")

      model.generate([user_message])

      expect(model.calls.size).to eq(1)
      call = model.calls[0]
      expect(call.index).to eq(1)
      expect(call.messages).to eq([user_message])
      expect(call.timestamp).to be_a(Time)
    end

    it "raises error when no responses queued" do
      expect { model.generate([user_message]) }
        .to raise_error(RuntimeError, /No more queued responses/)
    end

    it "accepts tools_to_call_from parameter" do
      tool = instance_double(Smolagents::Tools::Tool, name: "search")
      model.queue_response("response")

      model.generate([user_message], tools_to_call_from: [tool])

      call = model.calls[0]
      expect(call.tools_to_call_from).to eq([tool])
    end

    it "returns responses in FIFO order" do
      model.queue_response("first")
      model.queue_response("second")
      model.queue_response("third")

      result1 = model.generate([user_message])
      result2 = model.generate([user_message])
      result3 = model.generate([user_message])

      expect(result1.content).to eq("first")
      expect(result2.content).to eq("second")
      expect(result3.content).to eq("third")
    end

    it "passes through additional keyword arguments" do
      model.queue_response("response")

      # Should not raise even with extra kwargs
      expect { model.generate([user_message], temperature: 0.7, max_tokens: 100) }
        .not_to raise_error
    end
  end

  describe "#reset!" do
    it "clears all calls" do
      model.queue_response("response")
      model.generate([user_message])

      expect(model.calls).not_to be_empty

      model.reset!

      expect(model.calls).to be_empty
    end

    it "clears queued responses" do
      model.queue_response("response")

      model.reset!

      expect { model.generate([user_message]) }
        .to raise_error(RuntimeError, /No more queued responses/)
    end

    it "resets call_count to zero" do
      model.queue_response("response")
      model.generate([user_message])

      expect(model.call_count).to eq(1)

      model.reset!

      expect(model.call_count).to eq(0)
    end

    it "returns self for chaining" do
      result = model.reset!

      expect(result).to equal(model)
    end
  end

  describe "fluent API aliases" do
    describe "#returns" do
      it "is an alias for queue_response" do
        model.returns("answer")

        result = model.generate([user_message])

        expect(result.content).to eq("answer")
      end
    end

    describe "#returns_code" do
      it "is an alias for queue_code_action" do
        model.returns_code("puts 'hello'")

        result = model.generate([user_message])

        expect(result.content).to include("<code>")
      end
    end

    describe "#answers" do
      it "is an alias for queue_final_answer" do
        model.answers("42")

        result = model.generate([user_message])

        expect(result.content).to include("<code>")
        expect(result.content).to include("final_answer")
        expect(result.content).to include("42")
      end
    end
  end

  describe "method chaining" do
    it "supports chaining queue operations" do
      model.queue_response("step 1")
           .queue_response("step 2")
           .queue_response("step 3")

      expect(model.call_count).to eq(0)

      model.generate([user_message])
      expect(model.call_count).to eq(1)

      model.generate([user_message])
      expect(model.call_count).to eq(2)

      model.generate([user_message])
      expect(model.call_count).to eq(3)
    end

    it "allows mixing queue methods" do
      model.queue_response("text response")
           .queue_code_action("puts 'code'")
           .queue_final_answer("42")

      r1 = model.generate([user_message])
      expect(r1.content).to eq("text response")

      r2 = model.generate([user_message])
      expect(r2.content).to include("<code>")

      r3 = model.generate([user_message])
      expect(r3.content).to include("final_answer")
    end
  end

  describe "#last_call" do
    it "returns the last recorded call" do
      model.queue_response("response")
      model.generate([user_message])

      last = model.last_call

      expect(last).to equal(model.calls.last)
      expect(last.index).to eq(1)
    end

    it "returns nil when no calls made" do
      expect(model.last_call).to be_nil
    end
  end

  describe "#exhausted?" do
    it "returns true when no responses queued" do
      expect(model).to be_exhausted
    end

    it "returns false when responses remain" do
      model.queue_response("response")

      expect(model).not_to be_exhausted
    end

    it "returns true after all responses consumed" do
      model.queue_response("response")
      model.generate([user_message])

      expect(model).to be_exhausted
    end
  end

  describe "thread safety" do
    it "is thread-safe with concurrent generate calls" do
      model.queue_response("1")
           .queue_response("2")
           .queue_response("3")

      results = []
      threads = Array.new(3) do
        Thread.new do
          results << model.generate([user_message])
        end
      end

      threads.each(&:join)

      expect(results.size).to eq(3)
      expect(model.call_count).to eq(3)
    end

    it "is thread-safe with concurrent reset! calls" do
      model.queue_response("response")

      expect { model.reset!.reset! }.not_to raise_error
    end
  end

  describe "response message building" do
    it "builds ChatMessage with content" do
      model.queue_response("test content")

      result = model.generate([user_message])

      expect(result).to be_a(Smolagents::Types::ChatMessage)
      expect(result.content).to eq("test content")
      expect(result.role).to eq(Smolagents::Types::MessageRole::ASSISTANT)
    end

    it "builds ChatMessage with custom token usage" do
      model.queue_response("response", input_tokens: 100, output_tokens: 50)

      result = model.generate([user_message])

      expect(result.token_usage.input_tokens).to eq(100)
      expect(result.token_usage.output_tokens).to eq(50)
    end

    it "accepts ChatMessage as direct response" do
      custom_message = Smolagents::Types::ChatMessage.assistant("custom")
      model.queue_response(custom_message)

      result = model.generate([user_message])

      expect(result).to equal(custom_message)
    end
  end

  describe "call recording" do
    it "freezes recorded messages" do
      messages = [user_message]
      model.queue_response("response")

      model.generate(messages)

      recorded = model.calls[0].messages
      expect(recorded).to be_frozen
    end

    it "freezes recorded tools" do
      tool = instance_double(Smolagents::Tools::Tool)
      model.queue_response("response")

      model.generate([user_message], tools_to_call_from: [tool])

      recorded = model.calls[0].tools_to_call_from
      expect(recorded).to be_frozen
    end

    it "records timestamp for each call" do
      model.queue_response("response")
      before = Time.now
      model.generate([user_message])
      after = Time.now

      call_time = model.calls[0].timestamp

      expect(call_time).to be_between(before, after)
    end
  end

  describe "failure injection" do
    describe "#queue_failure" do
      it "raises the specified error class on generate" do
        model.queue_failure(ArgumentError, "Bad argument")

        expect { model.generate([user_message]) }
          .to raise_error(ArgumentError, "Bad argument")
      end

      it "raises error instance directly" do
        error = RuntimeError.new("Custom error")
        model.queue_failure(error)

        expect { model.generate([user_message]) }
          .to raise_error(RuntimeError, "Custom error")
      end

      it "still records the call before raising" do
        model.queue_failure(RuntimeError, "Test")

        expect { model.generate([user_message]) }.to raise_error(RuntimeError)

        expect(model.call_count).to eq(1)
        expect(model.calls.size).to eq(1)
      end

      it "returns self for chaining" do
        result = model.queue_failure(RuntimeError)

        expect(result).to equal(model)
      end

      it "works with custom error classes" do
        custom_error = Class.new(StandardError)
        model.queue_failure(custom_error, "Custom")

        expect { model.generate([user_message]) }
          .to raise_error(custom_error, "Custom")
      end
    end

    describe "#fail_next" do
      it "queues multiple failures" do
        model.fail_next(3, with: RuntimeError, message: "Retry me")
        model.queue_response("success")

        3.times do |i|
          expect { model.generate([user_message]) }
            .to raise_error(RuntimeError, "Retry me")
        end

        result = model.generate([user_message])
        expect(result.content).to eq("success")
      end

      it "defaults to 1 failure" do
        model.fail_next(with: RuntimeError)
        model.queue_response("after")

        expect { model.generate([user_message]) }.to raise_error(RuntimeError)

        result = model.generate([user_message])
        expect(result.content).to eq("after")
      end

      it "returns self for chaining" do
        result = model.fail_next(2, with: RuntimeError)

        expect(result).to equal(model)
      end
    end

    describe "#fail_then_succeed" do
      it "fails specified times then succeeds" do
        model.fail_then_succeed(2, with: IOError, then_respond: "Done!")

        expect { model.generate([user_message]) }.to raise_error(IOError)
        expect { model.generate([user_message]) }.to raise_error(IOError)

        result = model.generate([user_message])
        expect(result.content).to eq("Done!")
      end

      it "returns self for chaining" do
        result = model.fail_then_succeed(1, with: RuntimeError, then_respond: "OK")

        expect(result).to equal(model)
      end
    end

    describe "mixing failures and responses" do
      it "interleaves failures and successes" do
        model.queue_response("first")
             .queue_failure(RuntimeError, "fail")
             .queue_response("second")

        r1 = model.generate([user_message])
        expect(r1.content).to eq("first")

        expect { model.generate([user_message]) }.to raise_error(RuntimeError)

        r2 = model.generate([user_message])
        expect(r2.content).to eq("second")
      end

      it "supports complex sequences" do
        model.queue_final_answer("try 1")
             .fail_next(2, with: NetworkError)
             .queue_final_answer("recovered")

        r1 = model.generate([user_message])
        expect(r1.content).to include("final_answer")

        expect { model.generate([user_message]) }.to raise_error(NetworkError)
        expect { model.generate([user_message]) }.to raise_error(NetworkError)

        r2 = model.generate([user_message])
        expect(r2.content).to include("final_answer")
      end
    end
  end
end

# Define a test error class for failure injection tests
class NetworkError < StandardError; end
