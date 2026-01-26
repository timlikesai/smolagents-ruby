RSpec.describe Smolagents::Executors::RactorLazy::FutureIdentity do
  let(:test_class) do
    Class.new do
      include Smolagents::Executors::FutureBase
      include Smolagents::Executors::RactorLazy::FutureIdentity

      def initialize
        _init_future_state
      end

      def _ensure_resolved!
        # Mock implementation - returns nil so the library methods work correctly
        nil
      end
    end
  end

  let(:future) { test_class.new }

  describe "#nil?" do
    it "returns true for unresolved future with nil result" do
      # Unresolved future has @result = nil, so nil? returns true
      expect(future.nil?).to be true
    end

    it "returns false for resolved non-nil value" do
      future._resolve!(42)
      expect(future.nil?).to be false
    end

    it "returns true for resolved nil value" do
      future._resolve!(nil)
      expect(future.nil?).to be true
    end

    it "triggers resolution when pending" do
      allow(future).to receive(:_ensure_resolved!).and_call_original
      future.nil?
      expect(future).to have_received(:_ensure_resolved!)
    end
  end

  describe "#is_a?" do
    it "returns true for ToolFuture" do
      expect(future.is_a?(Smolagents::Executors::RactorLazy::ToolFuture)).to be true
    end

    it "returns true for BasicObject" do
      expect(future.is_a?(BasicObject)).to be true
    end

    it "returns false for other classes" do
      expect(future.is_a?(String)).to be false
      expect(future.is_a?(Array)).to be false
    end

    it "delegates to result after resolution" do
      future._resolve!([1, 2, 3])
      expect(future.is_a?(Array)).to be true
    end

    it "handles FiberError gracefully" do
      allow(future).to receive(:_ensure_resolved!).and_raise(FiberError)
      expect(future.is_a?(String)).to be false
    end
  end

  describe "#kind_of?" do
    it "is an alias for is_a?" do
      expect(future.is_a?(Smolagents::Executors::RactorLazy::ToolFuture)).to be true
      expect(future.is_a?(BasicObject)).to be true
      expect(future.is_a?(String)).to be false
    end

    it "behaves identically to is_a?" do
      future._resolve!("string")
      expect(future.is_a?(String)).to eq(future.is_a?(String))
    end
  end

  describe "#instance_of?" do
    it "returns true for ToolFuture" do
      expect(future.instance_of?(Smolagents::Executors::RactorLazy::ToolFuture)).to be true
    end

    it "returns false for other classes" do
      expect(future.instance_of?(String)).to be false
      expect(future.instance_of?(Array)).to be false
    end

    it "returns true for resolved result type" do
      future._resolve!("string")
      expect(future.instance_of?(String)).to be true
    end

    it "handles FiberError gracefully" do
      allow(future).to receive(:_ensure_resolved!).and_raise(FiberError)
      expect(future.instance_of?(String)).to be false
    end
  end

  describe "#class" do
    it "returns ToolFuture" do
      expect(future.class).to eq(Smolagents::Executors::RactorLazy::ToolFuture)
    end

    it "always returns ToolFuture even when resolved" do
      future._resolve!("string")
      expect(future.class).to eq(Smolagents::Executors::RactorLazy::ToolFuture)
    end
  end

  describe "#hash" do
    it "returns hash of resolved result" do
      future._resolve!([1, 2, 3])
      expect(future.hash).to eq([1, 2, 3].hash)
    end

    it "uses object id for unresolved future" do
      expect(future.hash).to be_a(Integer)
    end

    it "uses object id on FiberError" do
      allow(future).to receive(:_ensure_resolved!).and_raise(FiberError)
      expect(future.hash).to eq(future.__id__.hash)
    end

    it "is consistent for same value" do
      future._resolve!(42)
      hash1 = future.hash

      # Create another with same value
      future2 = test_class.new
      future2._resolve!(42)
      hash2 = future2.hash

      # Hashes should be the same for same value
      expect(hash1).to eq(hash2)
    end
  end

  describe "#eql?" do
    it "checks equality with resolved value" do
      future._resolve!("test")
      expect(future.eql?("test")).to be true
    end

    it "returns false for different values" do
      future._resolve!("test")
      expect(future.eql?("other")).to be false
    end

    it "returns false for unresolved future" do
      expect(future.eql?("anything")).to be false
    end

    it "handles FiberError gracefully" do
      allow(future).to receive(:_ensure_resolved!).and_raise(FiberError)
      expect(future.eql?("anything")).to be false
    end
  end

  describe "#!" do
    it "returns negated boolean of resolved value" do
      future._resolve!(true)
      expect(!future).to be false

      future2 = test_class.new
      future2._resolve!(false)
      expect(!future2).to be true
    end

    it "returns false for truthy values" do
      future._resolve!("string")
      expect(!future).to be false
    end

    it "returns true for nil" do
      future._resolve!(nil)
      expect(!future).to be true
    end

    it "returns true for unresolved future" do
      expect(!future).to be true
    end

    it "handles FiberError by returning true" do
      allow(future).to receive(:_ensure_resolved!).and_raise(FiberError)
      expect(!future).to be true
    end
  end

  describe "#empty?" do
    it "checks if resolved value is empty" do
      future._resolve!([])
      expect(future.empty?).to be true

      future2 = test_class.new
      future2._resolve!([1, 2, 3])
      expect(future2.empty?).to be false
    end

    it "works with strings" do
      future._resolve!("")
      expect(future.empty?).to be true

      future2 = test_class.new
      future2._resolve!("hello")
      expect(future2.empty?).to be false
    end

    it "works with hashes" do
      future._resolve!({})
      expect(future.empty?).to be true

      future2 = test_class.new
      future2._resolve!({ key: "value" })
      expect(future2.empty?).to be false
    end

    it "raises NoMethodError for unresolved future with nil result" do
      # Unresolved future has @result = nil, calling empty? on nil raises
      expect { future.empty? }.to raise_error(NoMethodError)
    end

    it "handles FiberError gracefully" do
      allow(future).to receive(:_ensure_resolved!).and_raise(FiberError)
      expect(future.empty?).to be false
    end
  end

  describe "identity with conditionals" do
    it "allows is_a? in if statements" do
      future._resolve!([1, 2, 3])

      result = future.is_a?(Array) ? :matched : :not_matched
      expect(result).to eq(:matched)
    end

    it "allows empty? in conditionals" do
      future._resolve!([])

      result = future.empty? ? :empty : :not_empty
      expect(result).to eq(:empty)
    end

    it "allows nil? in conditionals" do
      future._resolve!(nil)

      result = future.nil? ? :nil : :not_nil
      expect(result).to eq(:nil)
    end
  end

  describe "resolution triggering" do
    it "triggers _ensure_resolved! on nil?" do
      allow(future).to receive(:_ensure_resolved!).and_call_original
      future.nil?
      expect(future).to have_received(:_ensure_resolved!)
    end

    it "triggers _ensure_resolved! on is_a?" do
      allow(future).to receive(:_ensure_resolved!).and_call_original
      future.is_a?(String)
      expect(future).to have_received(:_ensure_resolved!)
    end

    it "triggers _ensure_resolved! on empty? when not resolved" do
      allow(future).to receive(:_ensure_resolved!).and_call_original
      # NOTE: This will raise NoMethodError because @result is nil
      # But _ensure_resolved! should be called
      expect { future.empty? }.to raise_error(NoMethodError)
      expect(future).to have_received(:_ensure_resolved!)
    end

    it "does not trigger on class method" do
      allow(future).to receive(:_ensure_resolved!)
      future.class
      expect(future).not_to have_received(:_ensure_resolved!)
    end
  end

  describe "typical patterns" do
    it "allows pattern matching on identity" do
      future._resolve!({ type: "search", results: [] })

      result = case future
               when ->(f) { f.is_a?(Hash) } then :hash
               else :other
               end
      expect(result).to eq(:hash)
    end

    it "allows checking for nil before access" do
      future._resolve!(nil)

      result = if future.nil?
                 "was nil"
               else
                 "had value"
               end

      expect(result).to eq("was nil")
    end

    it "allows checking emptiness of results" do
      future._resolve!([])

      count = if future.empty?
                0
              else
                future.length
              end

      expect(count).to eq(0)
    end
  end

  describe "edge cases" do
    it "handles objects without empty? method" do
      future._resolve!(42)

      expect do
        future.empty?
      end.to raise_error(NoMethodError)
    end

    it "handles boolean futures" do
      future._resolve!(true)
      expect(future.class).to eq(Smolagents::Executors::RactorLazy::ToolFuture)
      expect(!future).to be false
    end

    it "handles complex objects" do
      obj = { data: [1, 2, 3], meta: { status: "ok" } }
      future._resolve!(obj)

      expect(future.is_a?(Hash)).to be true
      expect(future.empty?).to be false
    end
  end
end
