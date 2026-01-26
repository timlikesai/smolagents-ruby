require_relative "../../../lib/smolagents/executors/final_answer_signal"

RSpec.describe Smolagents::Executors::FinalAnswerSignal do
  describe "initialization" do
    it "creates exception with a value" do
      signal = described_class.new(42)
      expect(signal.value).to eq(42)
    end

    it "creates exception with complex value" do
      value = { result: "answer", data: [1, 2, 3] }
      signal = described_class.new(value)
      expect(signal.value).to eq(value)
    end

    it "creates exception with nil value" do
      signal = described_class.new(nil)
      expect(signal.value).to be_nil
    end

    it "creates exception with string value" do
      signal = described_class.new("The answer is 42")
      expect(signal.value).to eq("The answer is 42")
    end
  end

  describe "exception behavior" do
    it "is a StandardError" do
      signal = described_class.new(42)
      expect(signal).to be_a(StandardError)
    end

    it "can be raised" do
      expect { raise described_class, 42 }.to raise_error(described_class)
    end

    it "can be caught" do
      caught = nil
      begin
        raise described_class, "final answer"
      rescue described_class => e
        caught = e
      end

      expect(caught).to be_a(described_class)
      expect(caught.value).to eq("final answer")
    end

    it "can be caught as StandardError" do
      caught = nil
      begin
        raise described_class, "result"
      rescue StandardError => e
        caught = e
      end

      expect(caught).to be_a(described_class)
    end

    it "has consistent message" do
      signal = described_class.new("anything")
      expect(signal.message).to eq("Final answer")
    end
  end

  describe "#value accessor" do
    it "returns the value passed at initialization" do
      value = { key: "value" }
      signal = described_class.new(value)
      expect(signal.value).to be(value)
    end

    it "returns different values for different signals" do
      signal1 = described_class.new(42)
      signal2 = described_class.new(100)

      expect(signal1.value).to eq(42)
      expect(signal2.value).to eq(100)
    end

    it "preserves object identity" do
      obj = Object.new
      signal = described_class.new(obj)
      expect(signal.value).to be(obj)
    end
  end

  describe "Ractor compatibility" do
    it "can be used to signal across Ractor boundaries" do
      # This is the main reason for this exception's existence
      signal = described_class.new("answer from ractor")
      expect { raise signal }.to raise_error(described_class) { |e| e.value == "answer from ractor" }
    end

    it "is used instead of FinalAnswerException in Ractor" do
      # Document the purpose
      signal = described_class.new("result")
      expect(signal).to be_a(Exception)
    end
  end

  describe "exception handling patterns" do
    it "works with rescue and extract value" do
      result = nil
      begin
        raise described_class, "42"
      rescue described_class => e
        result = e.value
      end

      expect(result).to eq("42")
    end

    it "works with ensure" do
      begin
        raise described_class, "result"
      rescue described_class
        # caught
      ensure
        cleanup_called = true
      end

      expect(cleanup_called).to be true
    end

    it "works with nested rescue" do
      caught = nil
      begin
        begin
          raise described_class, "inner"
        rescue described_class => e
          caught = e
          raise e
        end
      rescue described_class
        # outer rescue
      end

      expect(caught.value).to eq("inner")
    end
  end

  describe "different value types" do
    it "preserves string values" do
      signal = described_class.new("string result")
      expect(signal.value).to eq("string result")
    end

    it "preserves numeric values" do
      signal = described_class.new(42)
      expect(signal.value).to eq(42)
      expect(signal.value).to be_a(Integer)
    end

    it "preserves float values" do
      signal = described_class.new(3.14)
      expect(signal.value).to eq(3.14)
    end

    it "preserves array values" do
      array = [1, 2, 3, "result"]
      signal = described_class.new(array)
      expect(signal.value).to eq(array)
    end

    it "preserves hash values" do
      hash = { answer: 42, message: "found" }
      signal = described_class.new(hash)
      expect(signal.value).to eq(hash)
    end

    it "preserves boolean values" do
      signal_true = described_class.new(true)
      signal_false = described_class.new(false)

      expect(signal_true.value).to be true
      expect(signal_false.value).to be false
    end

    it "preserves object instances" do
      obj = Object.new
      signal = described_class.new(obj)
      expect(signal.value).to be(obj)
    end
  end

  describe "comparison and equality" do
    it "signals with same value have same message equality" do
      signal1 = described_class.new(42)
      signal2 = described_class.new(42)

      # Exception == compares messages, both have "Final answer"
      expect(signal1).to eq(signal2)
      # But they are different object instances
      expect(signal1).not_to equal(signal2)
    end

    it "same signal instance equals itself" do
      signal = described_class.new(42)
      expect(signal).to equal(signal)
    end
  end

  describe "backtrace" do
    it "has backtrace information" do
      raise described_class, "result"
    rescue described_class => e
      expect(e.backtrace).to be_a(Array)
      expect(e.backtrace).not_to be_empty
    end
  end

  describe "use case: agent final answer" do
    it "signals agent should stop and return answer" do
      agent_answer = nil
      begin
        # Simulate agent code calling final_answer()
        answer = "Found the solution"
        raise described_class, answer
      rescue described_class => e
        agent_answer = e.value
      end

      expect(agent_answer).to eq("Found the solution")
    end

    it "works with complex result objects" do
      result = nil
      begin
        answer = {
          status: "complete",
          reasoning: "checked all sources",
          solution: "42"
        }
        raise described_class, answer
      rescue described_class => e
        result = e.value
      end

      expect(result[:status]).to eq("complete")
      expect(result[:solution]).to eq("42")
    end
  end
end
