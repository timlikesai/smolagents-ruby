# Unit tests for FutureResolution module.
#
# Handles detecting, resolving, and unwrapping ToolFuture values
# including nested futures in collections.

RSpec.describe Smolagents::Executors::RactorLazy::FutureResolution do
  # Test harness that includes FutureResolution and provides required dependencies
  let(:harness_class) do
    Class.new do
      include Smolagents::Executors::RactorLazy::FutureResolution
      include Smolagents::Executors::RactorLazy::BatchHandling

      attr_reader :batch, :tool_port

      def initialize(batch: [], tool_port: nil)
        @batch = batch
        @tool_port = tool_port
      end
    end
  end

  let(:batch) { [] }
  let(:harness) { harness_class.new(batch:) }

  # Mock future for testing - avoids Fiber.yield on introspection
  class MockFuture
    attr_reader :tool_name, :args, :kwargs
    attr_accessor :result, :error

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
      @result = value
      @resolved = true
    end

    def _reject!(err)
      @error = err
      @resolved = true
    end

    def _resolved? = @resolved
    def _pending? = !@resolved
    def _result = @result
    def _error = @error
    def _future? = true

    # For type checks
    def is_a?(klass)
      klass == Smolagents::Executors::RactorLazy::ToolFuture || super
    end

    def respond_to?(method, _ = false)
      return true if method == :_future?

      super
    end

    def inspect
      return "#<Future:pending #{@tool_name}>" unless @resolved

      "#<Future:resolved #{@tool_name} => #{@result.inspect[0, 50]}>"
    end
  end

  def create_mock_future(name, batch: self.batch)
    MockFuture.new(name, [], {}, batch)
  end

  describe "#tool_future?" do
    it "returns true for ToolFuture" do
      future = create_mock_future("test")

      expect(harness.tool_future?(future)).to be true
    end

    it "returns false for nil" do
      expect(harness.tool_future?(nil)).to be false
    end

    it "returns false for regular values" do
      expect(harness.tool_future?("string")).to be false
      expect(harness.tool_future?(42)).to be false
      expect(harness.tool_future?([1, 2, 3])).to be false
      expect(harness.tool_future?({ a: 1 })).to be false
    end

    it "returns false for objects without _future? method" do
      obj = Object.new

      expect(harness.tool_future?(obj)).to be false
    end

    it "handles objects that raise on respond_to?" do
      problematic = BasicObject.new

      expect(harness.tool_future?(problematic)).to be false
    end
  end

  describe "#unwrap_future" do
    context "with nil" do
      it "returns nil" do
        expect(harness.unwrap_future(nil)).to be_nil
      end
    end

    context "with resolved future" do
      it "returns the result" do
        future = create_mock_future("test")
        future._resolve!("result")

        expect(harness.unwrap_future(future)).to eq("result")
      end
    end

    context "with rejected future" do
      it "raises the error" do
        future = create_mock_future("test")
        future._reject!("something failed")

        expect { harness.unwrap_future(future) }.to raise_error("something failed")
      end
    end

    context "with unresolved future" do
      it "returns inspect string" do
        future = create_mock_future("test")

        result = harness.unwrap_future(future)

        expect(result).to include("Future:pending")
      end
    end

    context "with regular values" do
      it "returns strings as-is" do
        expect(harness.unwrap_future("hello")).to eq("hello")
      end

      it "returns numbers as-is" do
        expect(harness.unwrap_future(42)).to eq(42)
      end

      it "returns symbols as-is" do
        expect(harness.unwrap_future(:symbol)).to eq(:symbol)
      end
    end

    context "with arrays" do
      it "unwraps futures in arrays" do
        f1 = create_mock_future("a")
        f1._resolve!("result_a")

        f2 = create_mock_future("b")
        f2._resolve!("result_b")

        result = harness.unwrap_future([f1, "literal", f2])

        expect(result).to eq(%w[result_a literal result_b])
      end

      it "returns empty array as-is" do
        expect(harness.unwrap_future([])).to eq([])
      end

      it "handles nested arrays" do
        f = create_mock_future("test")
        f._resolve!("nested")

        result = harness.unwrap_future([[f], [1, 2]])

        expect(result).to eq([["nested"], [1, 2]])
      end
    end

    context "with hashes" do
      it "unwraps futures in hash values" do
        f = create_mock_future("test")
        f._resolve!("value")

        result = harness.unwrap_future({ key: f, other: "literal" })

        expect(result).to eq({ key: "value", other: "literal" })
      end

      it "returns empty hash as-is" do
        expect(harness.unwrap_future({})).to eq({})
      end

      it "handles nested hashes" do
        f = create_mock_future("test")
        f._resolve!("deep")

        result = harness.unwrap_future({ outer: { inner: f } })

        expect(result).to eq({ outer: { inner: "deep" } })
      end
    end
  end

  describe "#unwrap_tool_future" do
    it "returns result for resolved future" do
      future = create_mock_future("test")
      future._resolve!("result")

      expect(harness.unwrap_tool_future(future)).to eq("result")
    end

    it "raises for rejected future" do
      future = create_mock_future("test")
      future._reject!("error message")

      expect { harness.unwrap_tool_future(future) }.to raise_error("error message")
    end

    it "returns inspect for unresolved future" do
      future = create_mock_future("test")

      result = harness.unwrap_tool_future(future)

      expect(result).to include("pending")
    end
  end

  describe "#unwrap_collection" do
    it "maps array elements through unwrap_future" do
      f = create_mock_future("test")
      f._resolve!("unwrapped")

      result = harness.unwrap_collection([f, "plain"])

      expect(result).to eq(%w[unwrapped plain])
    end

    it "transforms hash values through unwrap_future" do
      f = create_mock_future("test")
      f._resolve!("unwrapped")

      result = harness.unwrap_collection({ key: f, other: "plain" })

      expect(result).to eq({ key: "unwrapped", other: "plain" })
    end

    it "returns non-collections as-is" do
      expect(harness.unwrap_collection("string")).to eq("string")
      expect(harness.unwrap_collection(42)).to eq(42)
      expect(harness.unwrap_collection(nil)).to be_nil
    end
  end

  describe "#resolve_all_pending", :slow do
    before do
      @response_queue = []
      allow(Ractor).to receive(:receive) { @response_queue.shift }
    end

    def queue_batch_response(results)
      @response_queue << { results: }
    end

    # Create mock tool port for harness
    let(:mock_tool_port) do
      double("ToolPort").tap do |port| # -- duck-typed tool port
        allow(port).to receive(:send)
      end
    end

    let(:harness) { harness_class.new(batch:, tool_port: mock_tool_port) }

    context "with nil" do
      it "does nothing" do
        harness.resolve_all_pending(nil)
        # No error, no batch execution
      end
    end

    context "with unresolved future" do
      it "triggers resolution" do
        f = create_mock_future("test")
        queue_batch_response([{ success: true, value: "resolved" }])

        harness.resolve_all_pending(f)

        expect(f._resolved?).to be true
        expect(f._result).to eq("resolved")
      end
    end

    context "with already resolved future" do
      it "does not trigger another resolution" do
        f = create_mock_future("test")
        f._resolve!("already done")

        harness.resolve_all_pending(f)

        expect(mock_tool_port).not_to have_received(:send)
      end
    end

    context "with array containing futures" do
      it "resolves all pending futures" do
        f1 = create_mock_future("a")
        f2 = create_mock_future("b")
        f2._resolve!("already resolved")

        queue_batch_response([{ success: true, value: "resolved_a" }])

        harness.resolve_all_pending([f1, f2, "literal"])

        expect(f1._result).to eq("resolved_a")
        expect(f2._result).to eq("already resolved")
      end
    end

    context "with hash containing futures" do
      it "resolves all pending futures in values" do
        f = create_mock_future("test")
        queue_batch_response([{ success: true, value: "resolved" }])

        harness.resolve_all_pending({ key: f, other: "literal" })

        expect(f._result).to eq("resolved")
      end
    end
  end

  describe "#resolve_pending_collection" do
    # This is tested indirectly via resolve_all_pending
    # but we test the recursive behavior here

    it "handles empty array" do
      harness.resolve_pending_collection([])
      # No error
    end

    it "handles empty hash" do
      harness.resolve_pending_collection({})
      # No error
    end

    it "ignores non-collections" do
      harness.resolve_pending_collection("string")
      harness.resolve_pending_collection(42)
      # No error
    end
  end
end
