# Tests for ES6 Promise-inspired combinators on ToolFuture.
#
# Tests .all, .race, .any, and .all_settled class methods.
# Uses Fiber context simulation for batch resolution.

RSpec.describe Smolagents::Executors::RactorLazy::FutureCombinators do
  let(:batch) { [] }
  let(:future_class) { Smolagents::Executors::RactorLazy::ToolFuture }

  def create_future(name)
    future_class.new(name, [], {}, batch)
  end

  # Helper to run code in Fiber context with batch resolution
  def with_fiber_context(&)
    fiber = Fiber.new(&)
    result = nil

    loop do
      yielded = fiber.resume
      break result = yielded unless fiber.alive?

      next unless yielded.is_a?(Hash) && yielded[:type] == :batch

      yielded[:futures].each { |f| f._resolve!("result_#{f.tool_name}") unless f._resolved? }
    end
  end

  # Helper that rejects specific futures
  def with_fiber_context_rejecting(reject_names, &)
    fiber = Fiber.new(&)
    result = nil

    loop do
      yielded = fiber.resume
      break result = yielded unless fiber.alive?

      next unless yielded.is_a?(Hash) && yielded[:type] == :batch

      yielded[:futures].each do |f|
        if reject_names.include?(f.tool_name)
          f._reject!("Error in #{f.tool_name}")
        else
          f._resolve!("result_#{f.tool_name}") unless f._resolved?
        end
      end
    end
  end

  describe ".all" do
    it "returns empty array for empty input" do
      result = with_fiber_context { future_class.all([]) }
      expect(result).to eq([])
    end

    it "resolves all futures and returns results in order" do
      f1 = create_future("a")
      f2 = create_future("b")
      f3 = create_future("c")

      result = with_fiber_context { future_class.all([f1, f2, f3]) }

      expect(result).to eq(%w[result_a result_b result_c])
    end

    it "fails fast on first error" do
      f1 = create_future("ok")
      f2 = create_future("fail")

      expect do
        with_fiber_context_rejecting(["fail"]) { future_class.all([f1, f2]) }
      end.to raise_error("Error in fail")
    end

    it "accepts a single future (not array)" do
      f1 = create_future("single")

      result = with_fiber_context { future_class.all(f1) }

      expect(result).to eq(["result_single"])
    end

    context "with pre-resolved futures" do
      it "returns results immediately without yielding" do
        f1 = create_future("a")
        f2 = create_future("b")
        f1._resolve!("pre_a")
        f2._resolve!("pre_b")

        # No Fiber context needed since already resolved
        result = future_class.all([f1, f2])

        expect(result).to eq(%w[pre_a pre_b])
      end
    end
  end

  describe ".race" do
    it "returns nil for empty input" do
      result = with_fiber_context { future_class.race([]) }
      expect(result).to be_nil
    end

    it "returns first resolved value" do
      f1 = create_future("first")
      f2 = create_future("second")

      # Pre-resolve f1 to simulate it winning
      f1._resolve!("winner")

      result = with_fiber_context { future_class.race([f1, f2]) }

      expect(result).to eq("winner")
    end

    it "raises error if first resolved is an error" do
      f1 = create_future("fast_fail")
      f2 = create_future("slow_success")

      f1._reject!("Fast failure")

      expect do
        with_fiber_context { future_class.race([f1, f2]) }
      end.to raise_error("Fast failure")
    end
  end

  describe ".any" do
    it "raises AggregateError for empty input" do
      expect do
        with_fiber_context { future_class.any([]) }
      end.to raise_error(Smolagents::Executors::RactorLazy::AggregateError, /No futures provided/)
    end

    it "returns first successful value" do
      f1 = create_future("fail")
      f2 = create_future("success")

      result = with_fiber_context_rejecting(["fail"]) { future_class.any([f1, f2]) }

      expect(result).to eq("result_success")
    end

    it "raises AggregateError if all fail" do
      f1 = create_future("fail1")
      f2 = create_future("fail2")

      expect do
        with_fiber_context_rejecting(%w[fail1 fail2]) { future_class.any([f1, f2]) }
      end.to raise_error(Smolagents::Executors::RactorLazy::AggregateError) do |e|
        expect(e.errors).to eq(["Error in fail1", "Error in fail2"])
      end
    end

    it "ignores errors if at least one succeeds" do
      f1 = create_future("fail")
      f2 = create_future("ok")
      f3 = create_future("also_fail")

      result = with_fiber_context_rejecting(%w[fail also_fail]) { future_class.any([f1, f2, f3]) }

      expect(result).to eq("result_ok")
    end
  end

  describe ".all_settled" do
    it "returns empty array for empty input" do
      result = with_fiber_context { future_class.all_settled([]) }
      expect(result).to eq([])
    end

    it "returns fulfilled status for successful futures" do
      f1 = create_future("a")
      f2 = create_future("b")

      result = with_fiber_context { future_class.all_settled([f1, f2]) }

      expect(result).to eq([
                             { status: :fulfilled, value: "result_a" },
                             { status: :fulfilled, value: "result_b" }
                           ])
    end

    it "returns rejected status for failed futures" do
      f1 = create_future("ok")
      f2 = create_future("fail")

      result = with_fiber_context_rejecting(["fail"]) { future_class.all_settled([f1, f2]) }

      expect(result).to eq([
                             { status: :fulfilled, value: "result_ok" },
                             { status: :rejected, error: "Error in fail" }
                           ])
    end

    it "never raises, collects all results" do
      f1 = create_future("fail1")
      f2 = create_future("fail2")

      result = with_fiber_context_rejecting(%w[fail1 fail2]) { future_class.all_settled([f1, f2]) }

      expect(result).to eq([
                             { status: :rejected, error: "Error in fail1" },
                             { status: :rejected, error: "Error in fail2" }
                           ])
    end
  end
end

RSpec.describe Smolagents::Executors::RactorLazy::AggregateError do
  it "stores all errors" do
    errors = ["Error 1", "Error 2"]
    error = described_class.new("All failed", errors)

    expect(error.errors).to eq(errors)
    expect(error.message).to include("Error 1")
    expect(error.message).to include("Error 2")
  end
end
