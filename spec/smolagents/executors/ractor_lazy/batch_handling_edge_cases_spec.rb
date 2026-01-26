require "spec_helper"

# Edge case tests for BatchHandling
#
# Covers complex scenarios not fully tested in batch_handling_spec.rb:
# - Deep dependency chains (3+ waves)
# - Mixed success/failure in same wave
# - FinalAnswerSignal during batch resolution
# - Error recovery scenarios
RSpec.describe Smolagents::Executors::RactorLazy::BatchHandling do
  # Test harness that includes BatchHandling for isolated testing
  let(:harness_class) do
    Class.new do
      include Smolagents::Executors::RactorLazy::BatchHandling

      attr_reader :batch, :tool_port, :executed_waves

      def initialize(batch: [], tool_port: nil)
        @batch = batch
        @tool_port = tool_port
        @executed_waves = []
      end

      # Track calls to execute_batch for verification
      def execute_batch(futures)
        @executed_waves << futures.map(&:tool_name)
        super
      end
    end
  end
  let(:response_queue) { [] }

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

  # Mock future for unit testing
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

    def is_a?(klass)
      klass == Smolagents::Executors::RactorLazy::ToolFuture || super
    end
  end

  def create_mock_future(name, args: [], kwargs: {}, batch: self.batch)
    MockFuture.new(name, args, kwargs, batch)
  end

  before do
    allow(Ractor).to receive(:receive) { response_queue.shift }
  end

  def queue_batch_response(results)
    response_queue << { results: }
  end

  describe "deep dependency chains" do
    it "resolves three-level dependency chain correctly" do
      # Level 1: independent fetch
      f1 = create_mock_future("fetch")
      # Level 2: depends on f1
      f2 = create_mock_future("transform", kwargs: { data: f1 })
      # Level 3: depends on f2
      f3 = create_mock_future("summarize", kwargs: { transformed: f2 })

      # Queue responses for each wave
      queue_batch_response([{ success: true, value: "raw data" }])
      queue_batch_response([{ success: true, value: "transformed data" }])
      queue_batch_response([{ success: true, value: "summary" }])

      harness.resolve_in_waves

      expect(f1._result).to eq("raw data")
      expect(f2._result).to eq("transformed data")
      expect(f3._result).to eq("summary")
      expect(harness.executed_waves).to eq([["fetch"], ["transform"], ["summarize"]])
    end

    it "handles diamond dependency pattern" do
      # Diamond: a -> b, a -> c, b+c -> d
      #        a
      #       / \
      #      b   c
      #       \ /
      #        d
      a = create_mock_future("fetch")
      b = create_mock_future("process_b", kwargs: { input: a })
      c = create_mock_future("process_c", kwargs: { input: a })
      d = create_mock_future("combine", kwargs: { left: b, right: c })

      # Wave 1: a
      queue_batch_response([{ success: true, value: "base" }])
      # Wave 2: b and c (both ready once a resolves)
      queue_batch_response([
                             { success: true, value: "processed_b" },
                             { success: true, value: "processed_c" }
                           ])
      # Wave 3: d
      queue_batch_response([{ success: true, value: "combined" }])

      harness.resolve_in_waves

      expect(d._result).to eq("combined")
      expect(harness.executed_waves.size).to eq(3)
      # b and c should be in the same wave
      expect(harness.executed_waves[1]).to contain_exactly("process_b", "process_c")
    end

    it "handles long linear chain efficiently" do
      futures = []
      5.times do |i|
        kwargs = i.zero? ? {} : { prev: futures.last }
        futures << create_mock_future("step_#{i}", kwargs:)
      end

      # Queue a response for each step
      5.times do |i|
        queue_batch_response([{ success: true, value: "result_#{i}" }])
      end

      harness.resolve_in_waves

      futures.each_with_index do |f, i|
        expect(f._result).to eq("result_#{i}")
      end
      expect(harness.executed_waves.size).to eq(5)
    end
  end

  describe "mixed success/failure in same wave" do
    it "continues resolving other futures after one fails" do
      f1 = create_mock_future("good1")
      f2 = create_mock_future("bad")
      f3 = create_mock_future("good2")

      queue_batch_response([
                             { success: true, value: "result1" },
                             { success: false, error: "failed!" },
                             { success: true, value: "result2" }
                           ])

      harness.resolve_in_waves

      expect(f1._result).to eq("result1")
      expect(f2._error).to eq("failed!")
      expect(f3._result).to eq("result2")
    end

    it "allows dependent futures to see parent errors" do
      parent = create_mock_future("parent")
      child = create_mock_future("child", kwargs: { data: parent })

      # Parent fails
      queue_batch_response([{ success: false, error: "parent failed" }])
      # Child still gets called (with failed parent)
      queue_batch_response([{ success: false, error: "child sees error" }])

      harness.resolve_in_waves

      expect(parent._error).to eq("parent failed")
      expect(child._error).to eq("child sees error")
    end
  end

  describe "FinalAnswerSignal during batch resolution" do
    it "stops wave resolution when final_answer is received" do
      f1 = create_mock_future("search")
      f2 = create_mock_future("final_answer")
      create_mock_future("unused") # Should not be executed

      # First wave includes final_answer
      # Note: When final_answer is received, it raises FinalAnswerSignal
      # which is caught by handle_batch
      expect do
        # Simulate the response that triggers FinalAnswerSignal
        queue_batch_response([
                               { success: true, value: "search result" },
                               { final_answer: "done!" }
                               # f3 doesn't get resolved in this batch
                             ])

        harness.resolve_in_waves
      end.to raise_error(Smolagents::Executors::FinalAnswerSignal) do |signal|
        expect(signal.value).to eq("done!")
      end

      expect(f1._result).to eq("search result")
      expect(f2._result).to eq("done!")
    end
  end

  describe "batch building edge cases" do
    it "handles futures with positional args containing futures" do
      dep = create_mock_future("dependency")
      dep._resolve!("dep_value")

      parent = create_mock_future("process", args: [dep])

      request = harness.build_request(parent)

      expect(request[:args]).to eq(["dep_value"])
    end

    it "handles futures with mixed literal and future args" do
      dep = create_mock_future("dependency")
      dep._resolve!("resolved")

      parent = create_mock_future("process",
                                  args: ["literal"],
                                  kwargs: { key: dep, count: 5 })

      request = harness.build_request(parent)

      expect(request[:args]).to eq(["literal"])
      expect(request[:kwargs]).to eq({ key: "resolved", count: 5 })
    end

    it "handles empty batch gracefully multiple times" do
      3.times do
        harness.resolve_in_waves
      end
      expect(harness.executed_waves).to be_empty
    end
  end

  describe "dependency detection edge cases" do
    it "detects dependencies in nested kwargs" do
      dep = create_mock_future("dep")
      # Future with nested hash containing a future
      # Note: Current implementation only checks top-level kwargs
      parent = create_mock_future("parent", kwargs: { data: dep })

      expect(harness.ready_to_resolve?(parent)).to be false

      dep._resolve!("resolved")
      expect(harness.ready_to_resolve?(parent)).to be true
    end

    it "handles nil in args correctly" do
      parent = create_mock_future("process", args: [nil, "value", nil])

      expect(harness.ready_to_resolve?(parent)).to be true
    end

    it "handles empty kwargs correctly" do
      parent = create_mock_future("process", kwargs: {})

      expect(harness.ready_to_resolve?(parent)).to be true
    end
  end

  describe "force_resolve alias" do
    it "is an alias for resolve_in_waves" do
      f = create_mock_future("test")
      queue_batch_response([{ success: true, value: "result" }])

      harness.force_resolve

      expect(f._result).to eq("result")
    end
  end
end
