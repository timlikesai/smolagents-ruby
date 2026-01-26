# Unit tests for the outer ToolFuture layer.
#
# This is the orchestrator-facing ToolFuture (Executors::ToolFuture).
# For sandboxed agent code futures, see ractor_lazy/tool_future_spec.rb.
#
# Tests cover:
# - ToolFuture resolution and delegation
# - FutureBatch thread-local tracking
# - BatchYield data structure
# - TrackedToolProxy integration

RSpec.describe Smolagents::Executors::ToolFuture do
  before { Smolagents::Executors::FutureBatch.clear! }
  after { Smolagents::Executors::FutureBatch.clear! }

  let(:executor) { -> { "executed result" } }

  def create_future(name = "test", arguments: {}, exec: executor)
    described_class.new(tool_name: name, arguments:, executor: exec)
  end

  describe "#initialize" do
    it "stores tool_name, arguments, and executor" do
      future = create_future("search", arguments: { query: "ruby" })

      expect(future.tool_name).to eq("search")
      expect(future.arguments).to eq({ query: "ruby" })
      expect(future.executor).to eq(executor)
    end

    it "starts unresolved" do
      future = create_future

      expect(future._resolved?).to be false
    end

    it "registers with FutureBatch automatically" do
      future = create_future

      expect(Smolagents::Executors::FutureBatch.current).to include(future)
    end
  end

  describe "#_execute!" do
    it "executes the executor lambda" do
      called = false
      exec = lambda {
        called = true
        "result"
      }
      future = create_future(exec:)

      future._execute!

      expect(called).to be true
    end

    it "returns the result" do
      future = create_future

      result = future._execute!

      expect(result).to eq("executed result")
    end

    it "marks future as resolved" do
      future = create_future

      future._execute!

      expect(future._resolved?).to be true
    end

    it "stores the result" do
      future = create_future

      future._execute!

      expect(future._result).to eq("executed result")
    end

    it "is idempotent (only executes once)" do
      call_count = 0
      exec = lambda {
        call_count += 1
        "result"
      }
      future = create_future(exec:)

      future._execute!
      future._execute!

      expect(call_count).to eq(1)
    end

    context "when executor raises" do
      it "stores the error" do
        exec = -> { raise StandardError, "tool failed" }
        future = create_future(exec:)

        expect { future._execute! }.to raise_error(StandardError, "tool failed")

        expect(future._error).to be_a(StandardError)
        expect(future._error.message).to eq("tool failed")
      end

      it "marks as resolved even on error" do
        exec = -> { raise StandardError, "failed" }
        future = create_future(exec:)

        expect { future._execute! }.to raise_error(StandardError)

        expect(future._resolved?).to be true
      end
    end
  end

  describe "#_resolve!" do
    it "stores the resolved value" do
      future = create_future
      future._resolve!("injected result")

      expect(future._result).to eq("injected result")
    end

    it "marks future as resolved" do
      future = create_future
      future._resolve!("value")

      expect(future._resolved?).to be true
    end

    it "can resolve to nil" do
      future = create_future
      future._resolve!(nil)

      expect(future._resolved?).to be true
      expect(future._result).to be_nil
    end
  end

  describe "#_reject!" do
    it "stores the error" do
      future = create_future
      future._reject!(StandardError.new("error"))

      expect(future._error).to be_a(StandardError)
    end

    it "marks future as resolved" do
      future = create_future
      future._reject!(StandardError.new("error"))

      expect(future._resolved?).to be true
    end
  end

  describe "#inspect" do
    it "shows pending state for unresolved future" do
      future = create_future("search", arguments: { q: "test" })

      expect(future.inspect).to match(/ToolFuture:pending search/)
    end

    it "shows resolved state with truncated result" do
      future = create_future("search")
      future._resolve!("short result")

      expect(future.inspect).to match(/ToolFuture:resolved search =>/)
      expect(future.inspect).to include("short result")
    end

    it "truncates long results" do
      future = create_future("search")
      future._resolve!("x" * 100)

      expect(future.inspect.length).to be < 100
    end
  end

  describe "method delegation after resolution" do
    it "delegates methods to resolved value" do
      future = create_future
      future._resolve!("hello world")

      expect(future.upcase).to eq("HELLO WORLD")
    end

    it "delegates [] indexing" do
      future = create_future
      future._resolve!([1, 2, 3])

      expect(future[1]).to eq(2)
    end

    it "delegates each iteration" do
      future = create_future
      future._resolve!([1, 2, 3])

      collected = future.map { |x| x }

      expect(collected).to eq([1, 2, 3])
    end

    it "delegates ==" do
      future = create_future
      future._resolve!(42)

      expect(future == 42).to be true
      expect(future == 99).to be false
    end

    it "delegates to_s" do
      future = create_future
      future._resolve!("hello")

      expect(future.to_s).to eq("hello")
    end

    it "delegates to_a" do
      future = create_future
      future._resolve!([1, 2, 3])

      expect(future.to_a).to eq([1, 2, 3])
    end

    it "delegates to_h" do
      future = create_future
      future._resolve!({ a: 1, b: 2 })

      expect(future.to_h).to eq({ a: 1, b: 2 })
    end

    it "delegates respond_to_missing?" do
      future = create_future
      future._resolve!("hello")

      expect(future.respond_to?(:upcase)).to be true
      expect(future.respond_to?(:nonexistent_method)).to be false
    end
  end
end

RSpec.describe Smolagents::Executors::FutureBatch do
  before { described_class.clear! }
  after { described_class.clear! }

  describe ".current" do
    it "returns thread-local array" do
      expect(described_class.current).to eq([])
    end

    it "isolates batches between threads" do
      future1 = Smolagents::Executors::ToolFuture.new(
        tool_name: "main_thread",
        arguments: {},
        executor: -> { "main" }
      )

      thread_batch = Thread.new { described_class.current }.value

      expect(described_class.current).to include(future1)
      expect(thread_batch).to eq([])
    end
  end

  describe ".register" do
    it "adds future to current batch" do
      future = Smolagents::Executors::ToolFuture.new(
        tool_name: "test",
        arguments: {},
        executor: -> { "result" }
      )

      # ToolFuture auto-registers in initialize
      expect(described_class.current).to include(future)
    end
  end

  describe ".pending" do
    it "returns only unresolved futures" do
      f1 = Smolagents::Executors::ToolFuture.new(tool_name: "a", arguments: {}, executor: -> { "1" })
      f2 = Smolagents::Executors::ToolFuture.new(tool_name: "b", arguments: {}, executor: -> { "2" })
      f1._resolve!("done")

      pending = described_class.pending

      expect(pending).not_to include(f1)
      expect(pending).to include(f2)
    end

    it "returns empty array when all resolved" do
      f1 = Smolagents::Executors::ToolFuture.new(tool_name: "a", arguments: {}, executor: -> { "1" })
      f1._resolve!("done")

      expect(described_class.pending).to eq([])
    end
  end

  describe ".clear!" do
    it "empties the batch" do
      Smolagents::Executors::ToolFuture.new(tool_name: "test", arguments: {}, executor: -> { "r" })
      expect(described_class.current).not_to be_empty

      described_class.clear!

      expect(described_class.current).to eq([])
    end
  end

  describe ".resolve_all!" do
    context "with no pending futures" do
      it "returns without action" do
        expect { described_class.resolve_all! }.not_to raise_error
      end
    end

    context "outside Fiber context" do
      it "executes futures synchronously" do
        executed = []
        f1 = Smolagents::Executors::ToolFuture.new(
          tool_name: "a",
          arguments: {},
          executor: lambda {
            executed << "a"
            "result_a"
          }
        )
        f2 = Smolagents::Executors::ToolFuture.new(
          tool_name: "b",
          arguments: {},
          executor: lambda {
            executed << "b"
            "result_b"
          }
        )

        described_class.resolve_all!

        expect(executed).to contain_exactly("a", "b")
        expect(f1._resolved?).to be true
        expect(f2._resolved?).to be true
      end
    end

    context "inside Fiber context" do
      it "yields BatchYield to orchestrator" do
        yielded = nil
        fiber = Fiber.new do
          # Simulate being inside FiberExecution context
          Thread.current[:smolagents_in_code_fiber] = true
          begin
            described_class.clear!
            Smolagents::Executors::ToolFuture.new(tool_name: "search", arguments: {}, executor: -> { "r" })
            Smolagents::Executors::ToolFuture.new(tool_name: "fetch", arguments: {}, executor: -> { "r" })
            described_class.resolve_all!
          ensure
            Thread.current[:smolagents_in_code_fiber] = false
          end
        end

        result = fiber.resume
        yielded = result if result.is_a?(Smolagents::Executors::BatchYield)

        expect(yielded).to be_a(Smolagents::Executors::BatchYield)
        expect(yielded.size).to eq(2)
        expect(yielded.tool_names).to contain_exactly("search", "fetch")
      end
    end
  end
end

RSpec.describe Smolagents::Executors::BatchYield do
  let(:futures) do
    [
      instance_double(Smolagents::Executors::ToolFuture, tool_name: "search"),
      instance_double(Smolagents::Executors::ToolFuture, tool_name: "fetch")
    ]
  end

  let(:batch_yield) { described_class.new(futures:) }

  describe "#tool_names" do
    it "returns list of tool names" do
      expect(batch_yield.tool_names).to eq(%w[search fetch])
    end
  end

  describe "#size" do
    it "returns count of futures" do
      expect(batch_yield.size).to eq(2)
    end
  end

  describe "#to_s" do
    it "shows tool count and names" do
      expect(batch_yield.to_s).to eq("BatchYield[2 tools: search, fetch]")
    end
  end
end

RSpec.describe Smolagents::Executors::Executor::TrackedToolProxy do
  let(:mock_tool) do
    Class.new do
      def name = "mock_tool"
      def call(query:) = "Result for: #{query}"
    end.new
  end

  let(:tracker) do
    Class.new do
      include Smolagents::Executors::Executor::ToolCallTracking

      def initialize = initialize_tool_call_tracking
    end.new
  end

  let(:proxy) { described_class.new(mock_tool, tracker) }

  before { Smolagents::Executors::FutureBatch.clear! }
  after { Smolagents::Executors::FutureBatch.clear! }

  describe "#call" do
    it "returns a ToolFuture with tool_name accessor" do
      result = proxy.call(query: "test")

      # ToolFuture extends BasicObject, verify via its accessors
      expect(result.tool_name).to eq("mock_tool")
      expect(result.arguments).to eq({ query: "test" })
    end

    it "returns ToolFuture that can be resolved" do
      future = proxy.call(query: "test")

      expect(future._resolved?).to be false
      future._execute!
      expect(future._resolved?).to be true
    end

    it "executor runs the actual tool" do
      future = proxy.call(query: "test")

      result = future._execute!

      expect(result).to eq("Result for: test")
    end

    it "records tool call with tracker" do
      future = proxy.call(query: "test")
      future._execute!

      calls = tracker.tool_calls
      expect(calls.size).to eq(1)
      expect(calls.first.tool_name).to eq("mock_tool")
      expect(calls.first.result).to eq("Result for: test")
    end
  end

  describe "method forwarding" do
    it "forwards other methods to underlying tool" do
      expect(proxy.name).to eq("mock_tool")
    end

    it "responds to underlying tool methods" do
      expect(proxy.respond_to?(:name)).to be true
      expect(proxy.respond_to?(:nonexistent)).to be false
    end
  end
end
