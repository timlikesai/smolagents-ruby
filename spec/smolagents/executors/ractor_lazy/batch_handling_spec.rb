# Unit tests for BatchHandling module.
#
# Tests wave-based resolution of tool futures including:
# - Independent futures resolved in single wave
# - Dependent futures resolved in multiple waves
# - Circular dependency detection
# - Error propagation

RSpec.describe Smolagents::Executors::RactorLazy::BatchHandling do
  # Test harness that includes BatchHandling for isolated testing
  let(:harness_class) do
    Class.new do
      include Smolagents::Executors::RactorLazy::BatchHandling

      attr_reader :batch, :tool_port, :executed_batches

      def initialize(batch: [], tool_port: nil)
        @batch = batch
        @tool_port = tool_port
        @executed_batches = []
      end

      # Track calls to execute_batch for verification
      def execute_batch(futures)
        @executed_batches << futures.map(&:tool_name)
        super
      end
    end
  end

  let(:mock_tool_port) { MockToolPort.new }
  let(:harness) { harness_class.new(batch:, tool_port: mock_tool_port) }
  let(:batch) { [] }

  # Minimal mock for Ractor communication
  class MockToolPort
    attr_reader :sent_requests, :responses

    def initialize
      @sent_requests = []
      @responses = []
    end

    def queue_response(response) = responses << response

    def send(request) = sent_requests << request
  end

  # Mock future for unit testing - avoids Fiber.yield on introspection
  # Real ToolFuture yields when respond_to? is called, breaking RSpec matchers
  class MockFuture
    attr_reader :tool_name, :args, :kwargs
    attr_accessor :result, :error, :resolved

    def initialize(name, args = [], kwargs = {}, batch = [])
      @tool_name = name
      @args = args
      @kwargs = kwargs
      @resolved = false
      @result = nil
      @error = nil
      batch << self
    end

    def _resolve!(value)
      self.result = value
      self.resolved = true
    end

    def _reject!(err)
      self.error = err
      self.resolved = true
    end

    def _resolved? = resolved
    def _pending? = !resolved
    def _result = result
    def _error = error
    def _future? = true

    # For BatchHandling type checks
    def is_a?(klass)
      klass == Smolagents::Executors::RactorLazy::ToolFuture || super
    end
  end

  # Create a mock future for unit testing
  def create_mock_future(name, args: [], kwargs: {}, batch: self.batch)
    MockFuture.new(name, args, kwargs, batch)
  end

  # Create a real future when needed for specific tests
  def create_real_future(name, args: [], kwargs: {}, batch: self.batch)
    Smolagents::Executors::RactorLazy::ToolFuture.new(name, args, kwargs, batch)
  end

  describe "#ready_to_resolve?" do
    it "returns true when future has no dependencies" do
      future = create_mock_future("search", kwargs: { query: "test" })

      expect(harness.ready_to_resolve?(future)).to be true
    end

    it "returns true when all dependencies are resolved" do
      dep = create_mock_future("fetch")
      dep._resolve!("fetched data")

      future = create_mock_future("process", kwargs: { data: dep })

      expect(harness.ready_to_resolve?(future)).to be true
    end

    it "returns false when any dependency is unresolved" do
      dep = create_mock_future("fetch")
      future = create_mock_future("process", kwargs: { data: dep })

      expect(harness.ready_to_resolve?(future)).to be false
    end

    it "handles mixed resolved and unresolved dependencies" do
      resolved_dep = create_mock_future("fetch")
      resolved_dep._resolve!("data")

      unresolved_dep = create_mock_future("compute")

      future = create_mock_future("combine", kwargs: { a: resolved_dep, b: unresolved_dep })

      expect(harness.ready_to_resolve?(future)).to be false
    end

    it "handles args array with future dependencies" do
      dep = create_mock_future("fetch")
      future = create_mock_future("process", args: [dep])

      expect(harness.ready_to_resolve?(future)).to be false

      dep._resolve!("data")
      expect(harness.ready_to_resolve?(future)).to be true
    end
  end

  describe "#select_ready" do
    it "selects all independent futures" do
      f1 = create_mock_future("search", kwargs: { q: "a" })
      f2 = create_mock_future("search", kwargs: { q: "b" })
      pending = [f1, f2]

      ready = harness.select_ready(pending)

      expect(ready.map(&:tool_name)).to eq(%w[search search])
      expect(ready.size).to eq(2)
    end

    it "excludes futures with unresolved dependencies" do
      independent = create_mock_future("fetch")
      dependent = create_mock_future("process", kwargs: { data: independent })
      pending = [independent, dependent]

      ready = harness.select_ready(pending)

      expect(ready.size).to eq(1)
      expect(ready.first.tool_name).to eq("fetch")
    end

    it "returns empty array when all have unresolved dependencies" do
      f1 = create_mock_future("a")
      f2 = create_mock_future("b", kwargs: { dep: f1 })
      f1_with_cycle = create_mock_future("c", kwargs: { dep: f2 })

      # Simulate cycle: all depend on each other indirectly
      pending = [f2, f1_with_cycle]

      ready = harness.select_ready(pending)

      expect(ready).to be_empty
    end
  end

  describe "#all_resolved?" do
    it "returns true for empty array" do
      expect(harness.all_resolved?([])).to be true
    end

    it "returns true for array of non-futures" do
      expect(harness.all_resolved?([1, "string", :symbol])).to be true
    end

    it "returns true when all futures are resolved" do
      f1 = create_mock_future("a")
      f1._resolve!("result1")

      f2 = create_mock_future("b")
      f2._resolve!("result2")

      expect(harness.all_resolved?([f1, f2])).to be true
    end

    it "returns false when any future is unresolved" do
      f1 = create_mock_future("a")
      f1._resolve!("result1")

      f2 = create_mock_future("b") # unresolved

      expect(harness.all_resolved?([f1, f2])).to be false
    end
  end

  describe "#build_request" do
    it "builds request with tool name and unwrapped args" do
      future = create_mock_future("search", args: ["positional"], kwargs: { query: "test" })

      request = harness.build_request(future)

      expect(request).to eq({
                              name: "search",
                              args: ["positional"],
                              kwargs: { query: "test" }
                            })
    end

    it "unwraps resolved futures in args" do
      dep = create_mock_future("fetch")
      dep._resolve!("fetched_data")

      future = create_mock_future("process", kwargs: { data: dep })

      request = harness.build_request(future)

      expect(request[:kwargs][:data]).to eq("fetched_data")
    end

    it "preserves unresolved futures as-is in args" do
      dep = create_mock_future("fetch") # unresolved
      future = create_mock_future("process", kwargs: { data: dep })

      request = harness.build_request(future)

      # Compare by tool_name since we can't use equality matcher on futures
      expect(request[:kwargs][:data].tool_name).to eq("fetch")
    end
  end

  describe "#unwrap_args" do
    it "unwraps resolved futures" do
      f = create_mock_future("a")
      f._resolve!("value")

      result = harness.unwrap_args([f, "literal", 42])

      expect(result).to eq(["value", "literal", 42])
    end

    it "preserves unresolved futures" do
      f = create_mock_future("a")

      result = harness.unwrap_args([f])

      expect(result.first.tool_name).to eq("a")
      expect(result.first._resolved?).to be false
    end
  end

  describe "#unwrap_kwargs" do
    it "unwraps resolved futures in values" do
      f = create_mock_future("a")
      f._resolve!("resolved_value")

      result = harness.unwrap_kwargs({ key: f, other: "literal" })

      expect(result).to eq({ key: "resolved_value", other: "literal" })
    end
  end

  describe "#apply_result" do
    it "resolves future on success" do
      future = create_mock_future("test")

      harness.apply_result(future, { success: true, value: "result" })

      expect(future._resolved?).to be true
      expect(future._result).to eq("result")
    end

    it "rejects future on failure" do
      future = create_mock_future("test")

      harness.apply_result(future, { success: false, error: "something failed" })

      expect(future._resolved?).to be true
      expect(future._error).to eq("something failed")
    end

    it "raises FinalAnswerSignal on final_answer result" do
      future = create_mock_future("final_answer")

      expect do
        harness.apply_result(future, { final_answer: "done" })
      end.to raise_error(Smolagents::Executors::FinalAnswerSignal) do |error|
        expect(error.value).to eq("done")
      end

      expect(future._resolved?).to be true
    end
  end

  describe "#raise_circular_dependency!" do
    it "raises with descriptive error message" do
      f1 = create_mock_future("tool_a")
      f2 = create_mock_future("tool_b")

      expect do
        harness.raise_circular_dependency!([f1, f2])
      end.to raise_error(RuntimeError, /Circular dependency.*tool_a.*tool_b/)
    end
  end

  describe "#resolve_futures" do
    it "applies results to corresponding futures" do
      f1 = create_mock_future("a")
      f2 = create_mock_future("b")

      results = [
        { success: true, value: "result_a" },
        { success: true, value: "result_b" }
      ]

      harness.resolve_futures([f1, f2], results)

      expect(f1._result).to eq("result_a")
      expect(f2._result).to eq("result_b")
    end
  end

  # Integration-style tests for resolve_in_waves
  # These test the full algorithm but mock Ractor.receive
  describe "#resolve_in_waves" do
    let(:response_queue) { [] }

    before do
      # Stub Ractor.receive to return queued responses
      allow(Ractor).to receive(:receive) { response_queue.shift }
    end

    def queue_batch_response(results)
      response_queue << { results: }
    end

    it "resolves independent futures in single wave" do
      f1 = create_mock_future("search", kwargs: { q: "a" })
      f2 = create_mock_future("search", kwargs: { q: "b" })

      queue_batch_response([
                             { success: true, value: "result_a" },
                             { success: true, value: "result_b" }
                           ])

      harness.resolve_in_waves

      expect(f1._result).to eq("result_a")
      expect(f2._result).to eq("result_b")
      expect(harness.executed_batches).to eq([%w[search search]])
    end

    it "resolves dependent futures in multiple waves" do
      f1 = create_mock_future("fetch")
      f2 = create_mock_future("process", kwargs: { data: f1 })

      # Wave 1: resolve f1
      queue_batch_response([{ success: true, value: "fetched" }])
      # Wave 2: resolve f2
      queue_batch_response([{ success: true, value: "processed" }])

      harness.resolve_in_waves

      expect(f1._result).to eq("fetched")
      expect(f2._result).to eq("processed")
      expect(harness.executed_batches).to eq([["fetch"], ["process"]])
    end

    it "detects circular dependencies" do
      # Create a situation where no futures can be resolved:
      # - f2 depends on external_dep (not in batch, unresolved)
      # This simulates a "stuck" state that triggers circular dependency detection
      cycle_batch = []
      external_dep = MockFuture.new("external", [], {}, []) # not in batch, stays unresolved
      MockFuture.new("stuck", [], { dep: external_dep }, cycle_batch)

      harness_stuck = harness_class.new(batch: cycle_batch, tool_port: mock_tool_port)

      expect do
        harness_stuck.resolve_in_waves
      end.to raise_error(RuntimeError, /Circular dependency/)
    end

    it "handles empty batch gracefully" do
      harness.resolve_in_waves
      expect(harness.executed_batches).to be_empty
    end

    it "handles already-resolved futures" do
      f = create_mock_future("test")
      f._resolve!("already_done")

      harness.resolve_in_waves

      expect(harness.executed_batches).to be_empty
      expect(f._result).to eq("already_done")
    end

    it "propagates errors without affecting other futures in batch" do
      f1 = create_mock_future("good")
      f2 = create_mock_future("bad")

      queue_batch_response([
                             { success: true, value: "good_result" },
                             { success: false, error: "bad_error" }
                           ])

      harness.resolve_in_waves

      expect(f1._result).to eq("good_result")
      expect(f2._error).to eq("bad_error")
    end
  end
end
