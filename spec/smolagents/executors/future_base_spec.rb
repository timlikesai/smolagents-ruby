require_relative "../../../lib/smolagents/executors/future_base"

RSpec.describe Smolagents::Executors::FutureBase do
  # Create a test class that includes FutureBase
  let(:future_class) do
    Class.new do
      include Smolagents::Executors::FutureBase

      def initialize = _init_future_state
    end
  end

  describe "#_init_future_state" do
    it "initializes resolution state" do
      future = future_class.new

      expect(future._resolved?).to be false
      expect(future._pending?).to be true
      expect(future._result).to be_nil
      expect(future._error).to be_nil
    end
  end

  describe "#_resolve!" do
    it "marks future as resolved" do
      future = future_class.new
      future._resolve!(42)

      expect(future._resolved?).to be true
      expect(future._pending?).to be false
    end

    it "stores the resolved value" do
      future = future_class.new
      future._resolve!("result")

      expect(future._result).to eq("result")
    end

    it "stores various value types" do
      values = [42, "string", [1, 2, 3], { key: "value" }, nil, true, 3.14]

      values.each do |value|
        future = future_class.new
        future._resolve!(value)
        expect(future._result).to eq(value)
      end
    end

    it "can be resolved multiple times (overwrites)" do
      future = future_class.new
      future._resolve!(42)
      future._resolve!(100)

      # Last resolution wins
      expect(future._result).to eq(100)
    end

    it "clears error when resolving" do
      future = future_class.new
      future._reject!("error")
      future._resolve!(42)

      expect(future._result).to eq(42)
      expect(future._error).to eq("error") # Still there, but _resolved is true
    end
  end

  describe "#_reject!" do
    it "marks future as resolved but with error" do
      future = future_class.new
      future._reject!("something failed")

      expect(future._resolved?).to be true
      expect(future._pending?).to be false
    end

    it "stores the error message" do
      future = future_class.new
      future._reject!("timeout")

      expect(future._error).to eq("timeout")
    end

    it "stores various error types" do
      errors = ["string error", 42, { message: "error" }, Exception.new("error")]

      errors.each do |error|
        future = future_class.new
        future._reject!(error)
        expect(future._error).to eq(error)
      end
    end

    it "can be rejected multiple times (overwrites)" do
      future = future_class.new
      future._reject!("first error")
      future._reject!("second error")

      expect(future._error).to eq("second error")
    end
  end

  describe "#_resolved?" do
    it "returns false for new future" do
      future = future_class.new
      expect(future._resolved?).to be false
    end

    it "returns true after resolution" do
      future = future_class.new
      future._resolve!(42)
      expect(future._resolved?).to be true
    end

    it "returns true after rejection" do
      future = future_class.new
      future._reject!("error")
      expect(future._resolved?).to be true
    end

    it "remains true after resolution" do
      future = future_class.new
      future._resolve!(42)
      expect(future._resolved?).to be true
      expect(future._resolved?).to be true
    end
  end

  describe "#_pending?" do
    it "returns true for new future" do
      future = future_class.new
      expect(future._pending?).to be true
    end

    it "returns false after resolution" do
      future = future_class.new
      future._resolve!(42)
      expect(future._pending?).to be false
    end

    it "returns false after rejection" do
      future = future_class.new
      future._reject!("error")
      expect(future._pending?).to be false
    end

    it "is opposite of _resolved?" do
      future = future_class.new
      expect(future._pending?).to eq(!future._resolved?)

      future._resolve!(42)
      expect(future._pending?).to eq(!future._resolved?)
    end
  end

  describe "#_result" do
    it "returns nil for unresolved future" do
      future = future_class.new
      expect(future._result).to be_nil
    end

    it "returns the resolved value" do
      future = future_class.new
      future._resolve!("result")
      expect(future._result).to eq("result")
    end

    it "returns nil if error is set" do
      future = future_class.new
      future._reject!("error")
      expect(future._result).to be_nil
    end

    it "works with falsy values" do
      future = future_class.new
      future._resolve!(false)
      expect(future._result).to be false

      future2 = future_class.new
      future2._resolve!(0)
      expect(future2._result).to eq(0)
    end
  end

  describe "#_error" do
    it "returns nil for new future" do
      future = future_class.new
      expect(future._error).to be_nil
    end

    it "returns nil for resolved future" do
      future = future_class.new
      future._resolve!(42)
      expect(future._error).to be_nil
    end

    it "returns error message when rejected" do
      future = future_class.new
      future._reject!("timeout error")
      expect(future._error).to eq("timeout error")
    end

    it "persists even if resolved afterwards" do
      future = future_class.new
      future._reject!("error")
      future._resolve!(42) # This overwrites _result but error remains
      expect(future._error).to eq("error")
    end
  end

  describe "#_future?" do
    it "returns true" do
      future = future_class.new
      expect(future._future?).to be true
    end

    it "returns true for resolved future" do
      future = future_class.new
      future._resolve!(42)
      expect(future._future?).to be true
    end

    it "is used for duck-typing" do
      future = future_class.new
      # Allows checking: obj.respond_to?(:_future?) || obj._future?
      expect { future._future? }.not_to raise_error
    end
  end

  describe "state transitions" do
    it "transitions from pending to resolved" do
      future = future_class.new
      expect(future._pending?).to be true
      expect(future._resolved?).to be false

      future._resolve!(42)

      expect(future._pending?).to be false
      expect(future._resolved?).to be true
    end

    it "transitions from pending to rejected" do
      future = future_class.new
      expect(future._pending?).to be true

      future._reject!("error")

      expect(future._pending?).to be false
      expect(future._resolved?).to be true
    end
  end

  describe "typical workflow" do
    it "models successful tool call" do
      future = future_class.new

      # Initially pending
      expect(future._pending?).to be true

      # Tool executes and resolves
      result = [{ title: "Result 1" }, { title: "Result 2" }]
      future._resolve!(result)

      # Now resolved with value
      expect(future._resolved?).to be true
      expect(future._result).to eq(result)
      expect(future._error).to be_nil
    end

    it "models failed tool call" do
      future = future_class.new
      expect(future._pending?).to be true

      # Tool fails
      future._reject!("Tool timeout after 5 seconds")

      # Now resolved with error
      expect(future._resolved?).to be true
      expect(future._error).to eq("Tool timeout after 5 seconds")
      expect(future._result).to be_nil
    end

    it "supports error recovery pattern" do
      future = future_class.new
      future._reject!("first attempt failed")

      # Retry by resolving
      future._resolve!("recovered")

      expect(future._resolved?).to be true
      expect(future._result).to eq("recovered")
    end
  end

  describe "threading safety concerns" do
    it "allows concurrent state access" do
      future = future_class.new

      # Both can be called, though in practice should be serialized
      future._resolve!(42)

      expect(future._result).to eq(42)
      expect(future._resolved?).to be true
    end
  end

  describe "integration pattern: BatchYield" do
    it "works with batch execution pattern" do
      futures = Array.new(3) { future_class.new }

      # All start pending
      expect(futures).to all(be_pending)

      # Resolve them
      futures.each_with_index do |f, i|
        f._resolve!(i * 10)
      end

      # All now resolved
      expect(futures.map(&:_result)).to eq([0, 10, 20])
    end

    def be_pending
      have_attributes(_pending?: true)
    end
  end

  describe "error handling patterns" do
    it "allows storing Exception objects" do
      future = future_class.new
      error = RuntimeError.new("something failed")

      future._reject!(error)

      expect(future._error).to be(error)
    end

    it "allows storing custom error information" do
      future = future_class.new
      error_info = { code: 500, message: "Server error", timestamp: Time.now }

      future._reject!(error_info)

      expect(future._error[:code]).to eq(500)
    end
  end
end
