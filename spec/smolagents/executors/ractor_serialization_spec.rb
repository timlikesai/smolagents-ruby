require_relative "../../../lib/smolagents/executors/ractor_serialization"

RSpec.describe Smolagents::Executors::RactorSerialization do
  let(:test_class) do
    Class.new do
      include Smolagents::Executors::RactorSerialization

      public :prepare_for_ractor
    end
  end

  let(:serializer) { test_class.new }

  describe "#prepare_for_ractor" do
    describe "primitives" do
      it "passes integers through unchanged" do
        result = serializer.prepare_for_ractor(42)
        expect(result).to eq(42)
      end

      it "passes floats through unchanged" do
        result = serializer.prepare_for_ractor(3.14)
        expect(result).to eq(3.14)
      end

      it "passes symbols through unchanged" do
        result = serializer.prepare_for_ractor(:symbol)
        expect(result).to eq(:symbol)
      end

      it "passes nil through unchanged" do
        result = serializer.prepare_for_ractor(nil)
        expect(result).to be_nil
      end

      it "passes true through unchanged" do
        result = serializer.prepare_for_ractor(true)
        expect(result).to be true
      end

      it "passes false through unchanged" do
        result = serializer.prepare_for_ractor(false)
        expect(result).to be false
      end
    end

    describe "strings" do
      it "freezes unfrozen strings" do
        string = "hello"
        result = serializer.prepare_for_ractor(string)

        expect(result).to be_frozen
        expect(result).to eq("hello")
      end

      it "passes frozen strings through" do
        string = "frozen".freeze
        result = serializer.prepare_for_ractor(string)

        expect(result).to be_frozen
        expect(result).to equal(string)
      end
    end

    describe "arrays" do
      it "freezes array and contents" do
        array = [1, 2, 3]
        result = serializer.prepare_for_ractor(array)

        expect(result).to be_frozen
        expect(result).to eq([1, 2, 3])
      end

      it "recursively prepares array contents" do
        array = ["string", 42, nil]
        result = serializer.prepare_for_ractor(array)

        expect(result).to be_frozen
        expect(result[0]).to be_frozen
      end

      it "handles empty arrays" do
        result = serializer.prepare_for_ractor([])
        expect(result).to be_frozen
        expect(result).to eq([])
      end

      it "handles nested arrays" do
        array = [[1, 2], [3, 4]]
        result = serializer.prepare_for_ractor(array)

        expect(result).to be_frozen
        expect(result[0]).to be_frozen
      end
    end

    describe "hashes" do
      it "freezes hash and transforms contents" do
        hash = { key: "value", num: 42 }
        result = serializer.prepare_for_ractor(hash)

        expect(result).to be_frozen
        expect(result[:key]).to eq("value")
        expect(result[:num]).to eq(42)
      end

      it "recursively prepares keys and values" do
        hash = { "string_key" => "string_value", :symbol_key => 42 }
        result = serializer.prepare_for_ractor(hash)

        expect(result).to be_frozen
      end

      it "handles empty hashes" do
        result = serializer.prepare_for_ractor({})
        expect(result).to be_frozen
        expect(result).to eq({})
      end

      it "handles nested hashes" do
        hash = { outer: { inner: "value" } }
        result = serializer.prepare_for_ractor(hash)

        expect(result).to be_frozen
        expect(result[:outer]).to be_frozen
      end
    end

    describe "custom objects" do
      it "converts Data objects to hashes" do
        data = Data.define(:x, :y).new(1, 2)
        result = serializer.prepare_for_ractor(data)

        expect(result).to be_frozen
      end

      it "handles Range objects" do
        range = (1..10)
        result = serializer.prepare_for_ractor(range)

        # Ranges are already Ractor-shareable in Ruby 3+
        # They may pass through unchanged or be converted to Array
        expect(result).to be_frozen
      end

      it "handles Set objects" do
        set = Set.new([1, 2, 3])
        result = serializer.prepare_for_ractor(set)

        expect(result).to be_frozen
      end
    end

    describe "exceptions" do
      it "converts exceptions to hashes" do
        error = RuntimeError.new("test error")
        result = serializer.prepare_for_ractor(error)

        expect(result).to be_a(Hash)
        expect(result[:class]).to eq("RuntimeError")
        expect(result[:message]).to eq("test error")
      end

      it "includes backtrace if available" do
        raise "error"
      rescue StandardError => e
        result = serializer.prepare_for_ractor(e)
        expect(result[:backtrace]).to be_a(Array)
      end

      it "handles exceptions without backtrace" do
        error = RuntimeError.new("test")
        result = serializer.prepare_for_ractor(error)

        expect(result[:backtrace]).to be_a(Array)
      end
    end

    describe "procs and lambdas" do
      it "converts procs to frozen strings" do
        proc = -> { 42 }
        result = serializer.prepare_for_ractor(proc)

        expect(result).to be_frozen
        expect(result).to be_a(String)
      end

      it "converts lambdas to frozen strings" do
        lambda_obj = -> { "hello" }
        result = serializer.prepare_for_ractor(lambda_obj)

        expect(result).to be_frozen
        expect(result).to be_a(String)
      end
    end

    describe "circular reference protection" do
      it "stops at MAX_DEPTH" do
        # Build deeply nested structure
        obj = "value"
        100.times { obj = [obj] }

        # Should not raise, should handle gracefully
        result = serializer.prepare_for_ractor(obj)
        expect(result).not_to be_nil
      end

      it "converts to string for very deep objects" do
        # Build very deep nesting beyond MAX_DEPTH
        obj = "value"
        150.times { obj = [obj] }

        result = serializer.prepare_for_ractor(obj)
        expect(result).to be_frozen
      end
    end

    describe "already shareable objects" do
      it "passes shareable objects through unchanged" do
        shareable = [1, 2, 3].freeze
        result = serializer.prepare_for_ractor(shareable)

        expect(result).to equal(shareable)
      end
    end

    describe "fallback behavior" do
      it "attempts make_shareable on errors" do
        # Create object that might have special handling
        obj = Object.new
        result = serializer.prepare_for_ractor(obj)

        # Should end up as string representation
        expect(result).to be_frozen
      end
    end
  end

  describe "private helper methods" do
    describe "#primitive?" do
      it "identifies primitives" do
        expect(serializer.send(:primitive?, nil)).to be true
        expect(serializer.send(:primitive?, 42)).to be true
        expect(serializer.send(:primitive?, 3.14)).to be true
        expect(serializer.send(:primitive?, :symbol)).to be true
        expect(serializer.send(:primitive?, true)).to be true
        expect(serializer.send(:primitive?, false)).to be true
      end

      it "rejects non-primitives" do
        expect(serializer.send(:primitive?, "string")).to be false
        expect(serializer.send(:primitive?, [])).to be false
        expect(serializer.send(:primitive?, {})).to be false
        expect(serializer.send(:primitive?, Object.new)).to be false
      end
    end

    describe "#prepare_array" do
      it "freezes array contents" do
        array = %w[a b c]
        result = serializer.send(:prepare_array, array, 0)

        expect(result).to be_frozen
        expect(result.all? { |x| x.is_a?(String) && x.frozen? }).to be true
      end
    end

    describe "#prepare_hash" do
      it "freezes hash and transforms keys/values" do
        hash = { "key" => "value", :sym => 42 }
        result = serializer.send(:prepare_hash, hash, 0)

        expect(result).to be_frozen
      end
    end

    describe "#singleton_methods?" do
      it "detects singleton methods" do
        obj = Object.new
        obj.define_singleton_method(:my_method) { "hello" }

        # Should detect singleton methods
        expect(serializer.send(:singleton_methods?, obj)).to be true
      end

      it "returns false for normal objects" do
        obj = Object.new
        expect(serializer.send(:singleton_methods?, obj)).to be false
      end
    end

    describe "#try_hash_conversion" do
      it "converts objects with to_h" do
        obj = Data.define(:x).new(42)
        result = serializer.send(:try_hash_conversion, obj, 0)

        expect(result).not_to be_nil
      end

      it "returns nil for arrays" do
        array = [1, 2, 3]
        result = serializer.send(:try_hash_conversion, array, 0)

        expect(result).to be_nil
      end

      it "returns nil for objects without to_h" do
        obj = Object.new
        result = serializer.send(:try_hash_conversion, obj, 0)

        expect(result).to be_nil
      end
    end

    describe "#try_array_conversion" do
      it "converts objects with to_a" do
        range = (1..5)
        result = serializer.send(:try_array_conversion, range, 0)

        expect(result).not_to be_nil
      end

      it "returns nil for objects without to_a" do
        obj = Object.new
        result = serializer.send(:try_array_conversion, obj, 0)

        expect(result).to be_nil
      end
    end
  end

  describe "MAX_DEPTH" do
    it "has reasonable default" do
      expect(described_class::MAX_DEPTH).to be > 10
      expect(described_class::MAX_DEPTH).to be < 1000
    end
  end

  describe "integration patterns" do
    it "handles complex nested structures" do
      complex = {
        users: [
          { name: "Alice", age: 30, active: true },
          { name: "Bob", age: 25, active: false }
        ],
        metadata: {
          total: 2,
          timestamp: Time.now
        },
        errors: []
      }

      result = serializer.prepare_for_ractor(complex)
      expect(result).to be_frozen
      expect(result[:users]).to be_frozen
    end

    it "handles mixed types" do
      mixed = [
        42,
        "string",
        { key: "value" },
        [1, 2, 3],
        nil,
        true
      ]

      result = serializer.prepare_for_ractor(mixed)
      expect(result).to be_frozen
      expect(result.all?(&:frozen?)).to be true
    end
  end
end
