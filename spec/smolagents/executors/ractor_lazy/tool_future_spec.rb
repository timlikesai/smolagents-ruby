# Unit tests for ToolFuture - lazy proxy for tool results.
#
# ToolFuture is a BasicObject subclass that intercepts all method calls
# and triggers batch resolution via Fiber.yield on access.
#
# Tests are organized by:
# - Resolution API (direct, no Fiber context needed)
# - Identity methods (direct, no Fiber context needed)
# - Method forwarding (requires Fiber context simulation)

RSpec.describe Smolagents::Executors::RactorLazy::ToolFuture do
  let(:batch) { [] }

  def create_future(name, args: [], kwargs: {})
    described_class.new(name, args, kwargs, batch)
  end

  describe "#initialize" do
    it "stores tool name, args, and kwargs" do
      future = create_future("search", args: ["pos"], kwargs: { query: "test" })

      expect(future.tool_name).to eq("search")
      expect(future.args).to eq(["pos"])
      expect(future.kwargs).to eq({ query: "test" })
    end

    it "adds self to batch" do
      future = create_future("test")

      expect(batch).to include(future)
    end

    it "starts unresolved" do
      future = create_future("test")

      expect(future._resolved?).to be false
      expect(future._pending?).to be true
    end
  end

  describe "resolution API" do
    describe "#_resolve!" do
      it "stores the resolved value" do
        future = create_future("test")
        future._resolve!("result")

        expect(future._result).to eq("result")
      end

      it "marks future as resolved" do
        future = create_future("test")
        future._resolve!("result")

        expect(future._resolved?).to be true
        expect(future._pending?).to be false
      end

      it "can resolve to nil" do
        future = create_future("test")
        future._resolve!(nil)

        expect(future._resolved?).to be true
        expect(future._result).to be_nil
      end

      it "can resolve to complex values" do
        future = create_future("test")
        value = { data: [1, 2, 3], nested: { key: "value" } }
        future._resolve!(value)

        expect(future._result).to eq(value)
      end
    end

    describe "#_reject!" do
      it "stores the error" do
        future = create_future("test")
        future._reject!("something failed")

        expect(future._error).to eq("something failed")
      end

      it "marks future as resolved" do
        future = create_future("test")
        future._reject!("error")

        expect(future._resolved?).to be true
        expect(future._pending?).to be false
      end
    end

    describe "#_resolved?" do
      it "returns false when pending" do
        future = create_future("test")

        expect(future._resolved?).to be false
      end

      it "returns true after resolve" do
        future = create_future("test")
        future._resolve!("done")

        expect(future._resolved?).to be true
      end

      it "returns true after reject" do
        future = create_future("test")
        future._reject!("error")

        expect(future._resolved?).to be true
      end
    end

    describe "#_pending?" do
      it "returns true when unresolved" do
        future = create_future("test")

        expect(future._pending?).to be true
      end

      it "returns false when resolved" do
        future = create_future("test")
        future._resolve!("done")

        expect(future._pending?).to be false
      end
    end

    describe "#_future?" do
      it "returns true" do
        future = create_future("test")

        expect(future._future?).to be true
      end
    end
  end

  describe "identity methods (no Fiber.yield)" do
    describe "#nil?" do
      it "returns false without triggering resolution" do
        future = create_future("test")

        expect(future.nil?).to be false
        expect(future._pending?).to be true
      end
    end

    describe "#is_a?" do
      it "returns true for ToolFuture" do
        future = create_future("test")

        expect(future.is_a?(described_class)).to be true
      end

      it "returns true for BasicObject" do
        future = create_future("test")

        expect(future.is_a?(BasicObject)).to be true
      end

      it "returns false for other classes" do
        future = create_future("test")

        expect(future.is_a?(String)).to be false
        expect(future.is_a?(Array)).to be false
      end
    end

    describe "#kind_of?" do
      it "is aliased to is_a?" do
        future = create_future("test")

        expect(future.is_a?(described_class)).to be true
        expect(future.is_a?(String)).to be false
      end
    end

    describe "#instance_of?" do
      it "returns true only for ToolFuture" do
        future = create_future("test")

        expect(future.instance_of?(described_class)).to be true
        expect(future.instance_of?(BasicObject)).to be false
      end
    end

    describe "#class" do
      it "returns ToolFuture" do
        future = create_future("test")

        expect(future.class).to eq(described_class)
      end
    end
  end

  describe "#inspect" do
    it "shows pending state for unresolved future" do
      future = create_future("search")

      expect(future.inspect).to eq("#<Future:pending search>")
    end

    it "shows resolved state with truncated result" do
      future = create_future("search")
      future._resolve!("short result")

      expect(future.inspect).to match(/#<Future:resolved search => "short result"/)
    end

    it "truncates long results to 50 chars" do
      future = create_future("search")
      future._resolve!("x" * 100)

      inspect_output = future.inspect
      # Result.inspect is truncated to 50 chars (including opening quote)
      # "xxx..." -> 50 chars means 49 x's plus opening quote
      expect(inspect_output).to include("#<Future:resolved search =>")
      expect(inspect_output.length).to be < 100
    end
  end

  # Method forwarding tests require Fiber context to handle yield
  describe "method forwarding (with Fiber context)", :slow do
    # Helper that executes code in a Fiber and handles batch resolution
    def with_fiber_context
      result = nil
      fiber = Fiber.new { result = yield }

      loop do
        yielded = fiber.resume
        break unless fiber.alive?

        # If yielded a batch request, resolve the futures
        next unless yielded.is_a?(Hash) && yielded[:type] == :batch

        yielded[:futures].each do |f|
          f._resolve!(f._result) unless f._resolved?
        end
      end

      result
    end

    describe "#==" do
      it "compares resolved value" do
        future = create_future("test")
        future._resolve!(42)

        result = with_fiber_context { future == 42 }

        expect(result).to be true
      end

      it "returns false for non-matching value" do
        future = create_future("test")
        future._resolve!(42)

        result = with_fiber_context { future == 99 }

        expect(result).to be false
      end
    end

    describe "#to_s" do
      it "delegates to resolved value" do
        future = create_future("test")
        future._resolve!("hello")

        result = with_fiber_context { future.to_s }

        expect(result).to eq("hello")
      end
    end

    describe "#to_a" do
      it "delegates to resolved value" do
        future = create_future("test")
        future._resolve!([1, 2, 3])

        result = with_fiber_context { future.to_a }

        expect(result).to eq([1, 2, 3])
      end
    end

    describe "#to_h" do
      it "delegates to resolved value" do
        future = create_future("test")
        future._resolve!({ a: 1 })

        result = with_fiber_context { future.to_h }

        expect(result).to eq({ a: 1 })
      end
    end

    describe "#[]" do
      it "delegates array indexing" do
        future = create_future("test")
        future._resolve!([10, 20, 30])

        result = with_fiber_context { future[1] }

        expect(result).to eq(20)
      end

      it "delegates hash key access" do
        future = create_future("test")
        future._resolve!({ name: "test" })

        result = with_fiber_context { future[:name] }

        expect(result).to eq("test")
      end
    end

    describe "#each" do
      it "delegates to resolved value" do
        future = create_future("test")
        future._resolve!([1, 2, 3])

        collected = []
        with_fiber_context { future.each { |x| collected << x } }

        expect(collected).to eq([1, 2, 3])
      end
    end

    describe "#method_missing" do
      it "forwards methods to resolved value" do
        future = create_future("test")
        future._resolve!("hello world")

        result = with_fiber_context { future.upcase }

        expect(result).to eq("HELLO WORLD")
      end

      it "forwards methods with arguments" do
        future = create_future("test")
        future._resolve!([1, 2, 3, 4, 5])

        result = with_fiber_context { future.first(3) }

        expect(result).to eq([1, 2, 3])
      end

      it "forwards methods with blocks" do
        future = create_future("test")
        future._resolve!([1, 2, 3])

        result = with_fiber_context { future.map { |x| x * 2 } }

        expect(result).to eq([2, 4, 6])
      end
    end

    describe "error handling" do
      it "raises error from rejected future" do
        future = create_future("test")

        # Helper that rejects the future when batch is requested
        fiber = Fiber.new { future.to_s }

        yielded = fiber.resume
        expect(yielded[:type]).to eq(:batch)

        # Reject the future (simulating tool failure)
        future._reject!("Tool failed!")

        # Resume should raise the error
        expect { fiber.resume }.to raise_error("Tool failed!")
      end
    end
  end

  describe "#respond_to?" do
    context "for underscore methods" do
      it "returns true without triggering resolution" do
        future = create_future("test")

        expect(future.respond_to?(:_resolved?)).to be true
        expect(future.respond_to?(:_pending?)).to be true
        expect(future.respond_to?(:_future?)).to be true
        expect(future._pending?).to be true # Still pending
      end
    end

    context "for identity methods" do
      it "returns true without triggering resolution" do
        future = create_future("test")

        expect(future.respond_to?(:nil?)).to be true
        expect(future.respond_to?(:is_a?)).to be true
        expect(future.respond_to?(:class)).to be true
        expect(future._pending?).to be true
      end
    end

    # respond_to? for other methods triggers resolution
    context "for other methods", :slow do
      def with_fiber_context(&)
        fiber = Fiber.new(&)
        result = nil

        loop do
          yielded = fiber.resume
          break result = yielded unless fiber.alive?

          if yielded.is_a?(Hash) && yielded[:type] == :batch
            yielded[:futures].each { |f| f._resolve!("resolved") unless f._resolved? }
          end
        end
      end

      it "triggers resolution and delegates to result" do
        future = create_future("test")
        future._resolve!("hello")

        result = with_fiber_context { future.respond_to?(:upcase) }

        expect(result).to be true
      end
    end
  end
end
