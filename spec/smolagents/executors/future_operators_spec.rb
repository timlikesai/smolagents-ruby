RSpec.describe Smolagents::Executors::RactorLazy::FutureOperators do
  let(:test_class) do
    Class.new do
      include Smolagents::Executors::FutureBase
      include Smolagents::Executors::RactorLazy::FutureOperators

      def initialize
        _init_future_state
      end

      def _ensure_resolved!
        # Mock implementation - returns nil/false so || chaining works correctly
        nil
      end
    end
  end

  let(:future) { test_class.new }

  describe "comparison operators" do
    describe "#==" do
      it "compares with resolved value" do
        future._resolve!(42)
        expect(future == 42).to be true
        expect(future == 100).to be false
      end

      it "returns false for unresolved future" do
        expect(future == 42).to be false
      end

      it "works with strings" do
        future._resolve!("hello")
        expect(future == "hello").to be true
        expect(future == "world").to be false
      end

      it "works with arrays" do
        future._resolve!([1, 2, 3])
        expect(future == [1, 2, 3]).to be true
      end

      it "works with nil" do
        future._resolve!(nil)
        expect(future == nil).to be true # rubocop:disable Style/NilComparison
      end

      it "triggers resolution" do
        allow(future).to receive(:_ensure_resolved!)
        _comparison_result = (future == 42)
        expect(future).to have_received(:_ensure_resolved!)
      end
    end

    describe "#!=" do
      it "returns opposite of ==" do
        future._resolve!(42)
        expect(future != 42).to be false
        expect(future != 100).to be true
      end

      it "triggers resolution" do
        allow(future).to receive(:_ensure_resolved!)
        _comparison_result = (future != 42)
        expect(future).to have_received(:_ensure_resolved!)
      end
    end

    describe "#===" do
      it "case equality with resolved value" do
        future._resolve!(String)
        expect("hello".is_a?(String)).to be true
      end

      it "allows in case/when statements" do
        future._resolve!(42)
        matched = case future
                  when 42 then true
                  else false
                  end
        expect(matched).to be true
      end

      it "triggers resolution" do
        allow(future).to receive(:_ensure_resolved!)
        _case_result = (future === 42) # rubocop:disable Style/CaseEquality
        expect(future).to have_received(:_ensure_resolved!)
      end
    end

    describe "#<=>" do
      it "compares with resolved value" do
        future._resolve!(42)
        expect(future <=> 42).to eq(0)
        expect(future <=> 100).to eq(-1)
        expect(future <=> 10).to eq(1)
      end

      it "works with strings" do
        future._resolve!("b")
        expect(future <=> "a").to eq(1)
        expect(future <=> "b").to eq(0)
        expect(future <=> "c").to eq(-1)
      end

      it "returns nil for incomparable types" do
        future._resolve!("string")
        expect(future <=> 42).to be_nil
      end

      it "triggers resolution" do
        allow(future).to receive(:_ensure_resolved!)
        _comparison_result = (future <=> 42)
        expect(future).to have_received(:_ensure_resolved!)
      end
    end
  end

  describe "conversion operators" do
    describe "#to_s" do
      it "converts resolved value to string" do
        future._resolve!(42)
        expect(future.to_s).to eq("42")
      end

      it "converts array to string" do
        future._resolve!([1, 2, 3])
        expect(future.to_s).to include("1")
      end

      it "triggers resolution" do
        allow(future).to receive(:_ensure_resolved!)
        future.to_s
        expect(future).to have_received(:_ensure_resolved!)
      end
    end

    describe "#to_a" do
      it "converts resolved value to array" do
        future._resolve!([1, 2, 3])
        expect(future.to_a).to eq([1, 2, 3])
      end

      it "converts string to array via chars" do
        future._resolve!("abc".chars)
        expect(future.to_a).to eq(%w[a b c])
      end

      it "triggers resolution" do
        allow(future).to receive(:_ensure_resolved!)
        future.to_a
        expect(future).to have_received(:_ensure_resolved!)
      end
    end

    describe "#to_h" do
      it "converts resolved hash" do
        future._resolve!({ a: 1, b: 2 })
        expect(future.to_h).to eq({ a: 1, b: 2 })
      end

      it "converts object with to_h method" do
        obj = Data.define(:x, :y).new(1, 2)
        future._resolve!(obj)
        expect(future.to_h).to eq({ x: 1, y: 2 })
      end

      it "triggers resolution" do
        allow(future).to receive(:_ensure_resolved!)
        future.to_h
        expect(future).to have_received(:_ensure_resolved!)
      end
    end
  end

  describe "#each" do
    it "iterates over resolved array" do
      future._resolve!([1, 2, 3])
      collected = future.map { |x| x }

      expect(collected).to eq([1, 2, 3])
    end

    it "iterates over hash" do
      future._resolve!({ a: 1, b: 2 })
      collected = future.map { |k, v| [k, v] }

      expect(collected.size).to eq(2)
    end

    it "triggers resolution" do
      future._resolve!([1, 2, 3])
      allow(future).to receive(:_ensure_resolved!).and_call_original
      future.each { |_item| } # Just iterate, no return value needed
      expect(future).to have_received(:_ensure_resolved!)
    end
  end

  describe "#[]" do
    it "accesses array element" do
      future._resolve!([10, 20, 30])
      expect(future[0]).to eq(10)
      expect(future[1]).to eq(20)
      expect(future[2]).to eq(30)
    end

    it "accesses hash value" do
      future._resolve!({ a: 10, b: 20 })
      expect(future[:a]).to eq(10)
      expect(future[:b]).to eq(20)
    end

    it "accesses string character" do
      future._resolve!("hello")
      expect(future[0]).to eq("h")
      expect(future[1]).to eq("e")
    end

    it "triggers resolution" do
      future._resolve!([10, 20, 30])
      allow(future).to receive(:_ensure_resolved!).and_call_original
      future[0]
      expect(future).to have_received(:_ensure_resolved!)
    end
  end

  describe "#respond_to?" do
    it "returns true for future protocol methods" do
      expect(future.respond_to?(:_resolved?)).to be true
      expect(future.respond_to?(:_future?)).to be true
      expect(future.respond_to?(:_result)).to be true
    end

    it "returns true for builtin methods" do
      expect(future.respond_to?(:nil?)).to be true
      expect(future.respond_to?(:class)).to be true
      expect(future.respond_to?(:hash)).to be true
    end

    it "delegates to result for other methods" do
      future._resolve!([1, 2, 3])
      expect(future.respond_to?(:length)).to be true
      expect(future.respond_to?(:first)).to be true
    end

    it "returns false for non-existent methods on unresolved" do
      expect(future.respond_to?(:unknown_method)).to be false
    end

    it "accepts include_private parameter" do
      result = future.respond_to?(:nil?, include_private: true)
      expect(result).to be true
    end

    it "triggers resolution for result delegation" do
      allow(future).to receive(:_ensure_resolved!).and_call_original
      future.respond_to?(:length)
      expect(future).to have_received(:_ensure_resolved!)
    end
  end

  describe "#respond_to_missing?" do
    it "returns true for methods starting with underscore" do
      expect(future.send(:respond_to_missing?, :_custom)).to be true
    end

    it "returns true for builtin methods" do
      # respond_to_missing? doesn't check BUILTIN_METHODS, respond_to? does
      expect(future.respond_to?(:nil?)).to be true
    end

    it "delegates to result for other methods" do
      future._resolve!([1, 2, 3])
      expect(future.send(:respond_to_missing?, :length)).to be true
    end

    it "accepts include_private parameter" do
      result = future.send(:respond_to_missing?, :_custom, true)
      expect(result).to be true
    end
  end

  describe "#method_missing" do
    it "delegates unknown methods to result" do
      future._resolve!([1, 2, 3])
      expect(future.length).to eq(3)
      expect(future.first).to eq(1)
    end

    it "works with methods that take arguments" do
      future._resolve!([1, 2, 3])
      expect(future.include?(2)).to be true
    end

    it "works with methods that take blocks" do
      future._resolve!([1, 2, 3])
      result = future.map { |x| x * 2 }
      expect(result).to eq([2, 4, 6])
    end

    it "raises NoMethodError for undefined methods" do
      future._resolve!([1, 2, 3])
      expect { future.undefined_method }.to raise_error(NoMethodError)
    end

    it "triggers resolution before delegation" do
      allow(future).to receive(:_ensure_resolved!).and_call_original
      future._resolve!(42)
      future.to_s
      expect(future).to have_received(:_ensure_resolved!)
    end
  end

  describe "BUILTIN_METHODS" do
    it "contains expected methods" do
      builtin = described_class::BUILTIN_METHODS

      expect(builtin).to include(:nil?)
      expect(builtin).to include(:is_a?)
      expect(builtin).to include(:class)
      expect(builtin).to include(:hash)
      expect(builtin).to include(:empty?)
    end

    it "is a frozen array" do
      expect(described_class::BUILTIN_METHODS).to be_frozen
    end
  end

  describe "typical patterns" do
    it "allows arithmetic operations after resolution" do
      future._resolve!(42)
      expect(future <=> 40).to eq(1)
      expect(future <=> 42).to eq(0)
      expect(future <=> 50).to eq(-1)
    end

    it "allows string operations" do
      future._resolve!("hello")
      expect(future.to_s).to eq("hello")
      expect(future.to_s.upcase).to eq("HELLO")
    end

    it "allows array operations" do
      future._resolve!([1, 2, 3])
      expect(future[0]).to eq(1)
      expect(future.length).to eq(3)
    end

    it "allows combining comparisons" do
      future._resolve!(50)
      expect((future <=> 40) > 0).to be true
      expect((future <=> 60) < 0).to be true
      expect((future <=> 50) == 0).to be true
    end
  end

  describe "error handling" do
    it "propagates resolution errors" do
      allow(future).to receive(:_ensure_resolved!).and_raise(RuntimeError, "resolution failed")

      expect { future == 42 }.to raise_error(RuntimeError, "resolution failed")
    end

    it "propagates delegation errors" do
      future._resolve!([1, 2, 3])

      expect { future.call }.to raise_error(NoMethodError)
    end
  end

  describe "with different resolved values" do
    it "works with numeric futures" do
      future._resolve!(42)
      expect(future == 42).to be true
      expect(future <=> 50).to eq(-1)
    end

    it "works with string futures" do
      future._resolve!("test")
      expect(future == "test").to be true
      expect(future.to_s).to eq("test")
    end

    it "works with array futures" do
      future._resolve!([1, 2, 3])
      expect(future[0]).to eq(1)
      expect(future.to_a).to eq([1, 2, 3])
    end

    it "works with hash futures" do
      future._resolve!({ a: 1 })
      expect(future[:a]).to eq(1)
      expect(future.to_h).to eq({ a: 1 })
    end

    it "works with nil futures" do
      future._resolve!(nil)
      expect(future == nil).to be true # rubocop:disable Style/NilComparison
      expect(future.to_s).to eq("")
    end

    it "works with boolean futures" do
      future._resolve!(true)
      expect(future == true).to be true
    end
  end
end
