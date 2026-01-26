require "spec_helper"

RSpec.describe Smolagents::Executors::RactorLazy::FutureOperators do
  let(:batch) { [] }

  def create_future(name = "test")
    Smolagents::Executors::RactorLazy::ToolFuture.new(name, [], {}, batch)
  end

  # Helper to run code in Fiber context with batch resolution
  def with_fiber_context
    result = nil
    fiber = Fiber.new { result = yield }

    loop do
      yielded = fiber.resume
      break unless fiber.alive?

      # If yielded a batch request, resolve all pending futures
      next unless yielded.is_a?(Hash) && yielded[:type] == :batch

      yielded[:futures].each { |f| f._resolve!(f._result) unless f._resolved? }
    end

    result
  end

  describe "#==" do
    it "compares resolved value for equality" do
      future = create_future
      future._resolve!(42)

      result = with_fiber_context { future == 42 }

      expect(result).to be true
    end

    it "returns false for non-equal values" do
      future = create_future
      future._resolve!(42)

      result = with_fiber_context { future == 99 }

      expect(result).to be false
    end

    it "works with string comparison" do
      future = create_future
      future._resolve!("hello")

      result = with_fiber_context { future == "hello" }

      expect(result).to be true
    end
  end

  describe "#!=" do
    it "returns true for non-equal values" do
      future = create_future
      future._resolve!(42)

      result = with_fiber_context { future != 99 }

      expect(result).to be true
    end

    it "returns false for equal values" do
      future = create_future
      future._resolve!(42)

      result = with_fiber_context { future != 42 }

      expect(result).to be false
    end
  end

  # rubocop:disable Style/CaseEquality -- Testing case equality operator behavior
  describe "#===" do
    it "performs case equality on resolved value" do
      future = create_future
      future._resolve!("hello")

      result = with_fiber_context { future === "hello" }

      expect(result).to be true
    end

    it "works with regex patterns" do
      future = create_future
      future._resolve!(/\d+/)

      # Regex === string tests if regex matches
      result = with_fiber_context { future === "123" }

      expect(result).to be true
    end

    it "works with class matching" do
      future = create_future
      future._resolve!(String)

      result = with_fiber_context { future === "test" }

      expect(result).to be true
    end
  end
  # rubocop:enable Style/CaseEquality

  describe "#<=>" do
    it "compares numeric values" do
      future = create_future
      future._resolve!(5)

      expect(with_fiber_context { future <=> 3 }).to eq(1)
      expect(with_fiber_context { future <=> 5 }).to eq(0)
      expect(with_fiber_context { future <=> 7 }).to eq(-1)
    end

    it "compares string values" do
      future = create_future
      future._resolve!("banana")

      expect(with_fiber_context { future <=> "apple" }).to eq(1)
      expect(with_fiber_context { future <=> "banana" }).to eq(0)
      expect(with_fiber_context { future <=> "cherry" }).to eq(-1)
    end

    it "returns nil for incomparable types" do
      future = create_future
      future._resolve!("string")

      result = with_fiber_context { future <=> 42 }

      expect(result).to be_nil
    end
  end

  describe "#to_s" do
    it "converts resolved value to string" do
      future = create_future
      future._resolve!(42)

      result = with_fiber_context { future.to_s }

      expect(result).to eq("42")
    end

    it "works with array values" do
      future = create_future
      future._resolve!([1, 2, 3])

      result = with_fiber_context { future.to_s }

      expect(result).to eq("[1, 2, 3]")
    end
  end

  describe "#to_a" do
    it "converts resolved value to array" do
      future = create_future
      future._resolve!([1, 2, 3])

      result = with_fiber_context { future.to_a }

      expect(result).to eq([1, 2, 3])
    end

    it "converts hash to array of pairs" do
      future = create_future
      future._resolve!({ a: 1, b: 2 })

      result = with_fiber_context { future.to_a }

      expect(result).to eq([[:a, 1], [:b, 2]])
    end
  end

  describe "#to_h" do
    it "returns hash as-is" do
      future = create_future
      future._resolve!({ key: "value" })

      result = with_fiber_context { future.to_h }

      expect(result).to eq({ key: "value" })
    end

    it "converts array of pairs to hash" do
      future = create_future
      future._resolve!([[:a, 1], [:b, 2]])

      result = with_fiber_context { future.to_h }

      expect(result).to eq({ a: 1, b: 2 })
    end
  end

  describe "#each" do
    it "iterates over array elements" do
      future = create_future
      future._resolve!([1, 2, 3])

      collected = []
      with_fiber_context { future.each { |x| collected << x } }

      expect(collected).to eq([1, 2, 3])
    end

    it "iterates over hash key-value pairs" do
      future = create_future
      future._resolve!({ a: 1, b: 2 })

      collected = []
      with_fiber_context { future.each { |k, v| collected << [k, v] } }

      expect(collected).to eq([[:a, 1], [:b, 2]])
    end
  end

  describe "#[]" do
    it "accesses array by index" do
      future = create_future
      future._resolve!([10, 20, 30])

      result = with_fiber_context { future[1] }

      expect(result).to eq(20)
    end

    it "accesses hash by key" do
      future = create_future
      future._resolve!({ name: "test", value: 42 })

      name = with_fiber_context { future[:name] }
      value = with_fiber_context { future[:value] }

      expect(name).to eq("test")
      expect(value).to eq(42)
    end

    it "returns nil for missing key" do
      future = create_future
      future._resolve!({ a: 1 })

      result = with_fiber_context { future[:missing] }

      expect(result).to be_nil
    end
  end

  describe "#respond_to?" do
    it "returns true for underscore methods without triggering resolution" do
      future = create_future

      expect(future.respond_to?(:_resolved?)).to be true
      expect(future.respond_to?(:_pending?)).to be true
      expect(future.respond_to?(:_future?)).to be true
      expect(future._pending?).to be true # Still pending
    end

    it "returns true for builtin methods" do
      future = create_future

      expect(future.respond_to?(:nil?)).to be true
      expect(future.respond_to?(:is_a?)).to be true
      expect(future.respond_to?(:class)).to be true
      expect(future.respond_to?(:hash)).to be true
      expect(future.respond_to?(:eql?)).to be true
      expect(future.respond_to?(:empty?)).to be true
    end

    it "delegates to resolved value for other methods" do
      future = create_future
      future._resolve!("hello")

      result = with_fiber_context { future.respond_to?(:upcase) }

      expect(result).to be true
    end
  end

  describe "#method_missing" do
    it "forwards methods to resolved value" do
      future = create_future
      future._resolve!("hello world")

      result = with_fiber_context { future.upcase }

      expect(result).to eq("HELLO WORLD")
    end

    it "forwards methods with arguments" do
      future = create_future
      future._resolve!([1, 2, 3, 4, 5])

      result = with_fiber_context { future.first(3) }

      expect(result).to eq([1, 2, 3])
    end

    it "forwards methods with blocks" do
      future = create_future
      future._resolve!([1, 2, 3])

      result = with_fiber_context { future.map { |x| x * 2 } }

      expect(result).to eq([2, 4, 6])
    end

    it "chains method calls" do
      future = create_future
      future._resolve!("  hello  ")

      result = with_fiber_context { future.strip.upcase }

      expect(result).to eq("HELLO")
    end
  end

  describe "BUILTIN_METHODS constant" do
    it "includes expected methods" do
      builtin = Smolagents::Executors::RactorLazy::FutureOperators::BUILTIN_METHODS

      expect(builtin).to include(:nil?)
      expect(builtin).to include(:is_a?)
      expect(builtin).to include(:kind_of?)
      expect(builtin).to include(:instance_of?)
      expect(builtin).to include(:class)
      expect(builtin).to include(:hash)
      expect(builtin).to include(:eql?)
      expect(builtin).to include(:empty?)
      expect(builtin).to include(:!)
      expect(builtin).to include(:===)
      expect(builtin).to include(:<=>)
    end

    it "is frozen" do
      builtin = Smolagents::Executors::RactorLazy::FutureOperators::BUILTIN_METHODS

      expect(builtin).to be_frozen
    end
  end
end
