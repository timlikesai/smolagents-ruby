require "spec_helper"

# Edge case tests for FiberExecutor
#
# Covers scenarios not fully tested in fiber_executor_spec.rb:
# - handle_batch returning [:final_answer, value]
# - Error recovery patterns
# - Complex batch resolution scenarios
RSpec.describe Smolagents::Executors::RactorLazy::FiberExecutor do
  let(:output) { StringIO.new }
  let(:batch) { [] }
  let(:sent_requests) { [] }
  let(:sent_results) { [] }

  let(:tool_port) do
    requests = sent_requests
    Object.new.tap do |port|
      port.define_singleton_method(:sent_requests) { requests }
      port.define_singleton_method(:send) { |req| requests << req }
    end
  end

  let(:result_port) do
    results = sent_results
    Object.new.tap do |port|
      port.define_singleton_method(:sent_results) { results }
      port.define_singleton_method(:send) { |res| results << res }
    end
  end

  let(:max_ops) { 100_000 }

  let(:ctx) do
    obj = Object.new
    obj.define_singleton_method(:puts) { |*args| output.puts(*args) }
    obj.define_singleton_method(:print) { |*args| output.print(*args) }
    obj
  end

  let(:executor) do
    described_class.new(ctx, output, batch, tool_port, result_port, max_ops)
  end

  describe "#handle_batch with final_answer" do
    before do
      allow(Ractor).to receive(:receive).and_return({ results: [] })
    end

    it "returns [:final_answer, value] when FinalAnswerSignal is raised" do
      # Setup: handle_batch raises FinalAnswerSignal during resolution
      # This happens when a tool call returns a final_answer result

      # Create mock future
      mock_future = build_mock_future("final_answer", [], {}, batch)

      # Stub Ractor.receive to return final_answer result
      allow(Ractor).to receive(:receive).and_return({
                                                      results: [{ final_answer: "the answer" }]
                                                    })

      result = executor.send(:handle_batch, [mock_future])

      expect(result).to eq([:final_answer, "the answer"])
    end

    it "returns nil on normal batch resolution" do
      mock_future = build_mock_future("search", [], {}, batch)

      allow(Ractor).to receive(:receive).and_return({
                                                      results: [{ success: true, value: "result" }]
                                                    })

      result = executor.send(:handle_batch, [mock_future])

      expect(result).to be_nil
    end
  end

  describe "#process_fiber_result with batch containing final_answer" do
    before do
      allow(Ractor).to receive(:receive).and_return({ results: [] })
    end

    it "sends final result and returns false when batch yields final_answer" do
      # Mock handle_batch to return final_answer
      allow(executor).to receive(:handle_batch).and_return([:final_answer, "done"])

      result = executor.send(:process_fiber_result, { type: :batch, futures: [] })

      expect(result).to be false
      expect(result_port.sent_results.size).to eq(1)
      expect(result_port.sent_results.first[:is_final]).to be true
      expect(result_port.sent_results.first[:result]).to eq("done")
    end
  end

  describe "error recovery patterns" do
    before do
      allow(Ractor).to receive(:receive).and_return({ results: [] })
    end

    it "handles multiple sequential errors gracefully" do
      # First execution errors
      executor.execute("raise 'error1'")
      expect(result_port.sent_results.last[:success]).to be false
      expect(result_port.sent_results.last[:error]).to include("error1")

      # Second execution also errors
      executor.execute("raise 'error2'")
      expect(result_port.sent_results.last[:success]).to be false
      expect(result_port.sent_results.last[:error]).to include("error2")

      # Third execution succeeds
      executor.execute("42")
      expect(result_port.sent_results.last[:success]).to be true
      expect(result_port.sent_results.last[:result]).to eq(42)
    end

    it "clears batch between executions after error" do
      batch << "leftover"

      executor.execute("raise 'oops'")

      expect(batch).to be_empty
    end

    it "resets output buffer between executions" do
      output.puts("previous output")

      executor.execute("42")

      # The logs should not include previous output
      result = result_port.sent_results.first
      expect(result[:logs]).not_to include("previous output")
    end
  end

  describe "resolve_and_send error handling" do
    before do
      allow(Ractor).to receive(:receive).and_return({ results: [] })
    end

    it "catches FinalAnswerSignal during resolution" do
      # Create a mock that raises FinalAnswerSignal when accessed
      mock_future = Object.new
      def mock_future._future? = true
      def mock_future._resolved? = true
      def mock_future._error = nil

      def mock_future._result
        raise Smolagents::Executors::FinalAnswerSignal, "surprise final"
      end

      # resolve_all_pending will try to process this future
      allow(executor).to receive(:resolve_all_pending).and_raise(
        Smolagents::Executors::FinalAnswerSignal, "surprise final"
      )

      executor.send(:resolve_and_send, :result, mock_future)

      # Should have sent a final result
      expect(result_port.sent_results.last[:is_final]).to be true
      expect(result_port.sent_results.last[:result]).to eq("surprise final")
    end

    it "catches StandardError during resolution and sends error" do
      allow(executor).to receive(:resolve_all_pending).and_raise(
        RuntimeError, "resolution failed"
      )

      executor.send(:resolve_and_send, :result, "ignored")

      expect(result_port.sent_results.last[:success]).to be false
      expect(result_port.sent_results.last[:error]).to include("RuntimeError")
      expect(result_port.sent_results.last[:error]).to include("resolution failed")
    end
  end

  describe "unwrapping futures in results" do
    before do
      allow(Ractor).to receive(:receive).and_return({ results: [] })
    end

    it "unwraps resolved future in send_result" do
      mock_future = build_mock_future("test", [], {}, [])
      mock_future._resolve!("unwrapped value")

      executor.send(:send_result, mock_future)

      expect(result_port.sent_results.last[:result]).to eq("unwrapped value")
    end

    it "unwraps nested futures in arrays" do
      f1 = build_mock_future("a", [], {}, [])
      f2 = build_mock_future("b", [], {}, [])
      f1._resolve!("value_a")
      f2._resolve!("value_b")

      result = [f1, "literal", f2]
      executor.send(:send_result, result)

      expect(result_port.sent_results.last[:result]).to eq(%w[value_a literal value_b])
    end

    it "unwraps nested futures in hashes" do
      f = build_mock_future("test", [], {}, [])
      f._resolve!("hash_value")

      result = { key: f, other: 42 }
      executor.send(:send_result, result)

      expect(result_port.sent_results.last[:result]).to eq({ key: "hash_value", other: 42 })
    end
  end

  # Helper to build mock futures
  def build_mock_future(name, args, kwargs, batch_array)
    state = { resolved: false, result: nil, error: nil }
    future = Object.new
    define_future_accessors(future, name, args, kwargs, state)
    define_future_mutations(future, state)
    define_future_type_methods(future, name, state)
    batch_array << future
    future
  end

  def define_future_accessors(future, name, args, kwargs, state)
    future.define_singleton_method(:tool_name) { name }
    future.define_singleton_method(:args) { args }
    future.define_singleton_method(:kwargs) { kwargs }
    future.define_singleton_method(:_result) { state[:result] }
    future.define_singleton_method(:_error) { state[:error] }
  end

  def define_future_mutations(future, state)
    future.define_singleton_method(:_resolve!) { |v| state.merge!(result: v, resolved: true) }
    future.define_singleton_method(:_reject!) { |e| state.merge!(error: e, resolved: true) }
    future.define_singleton_method(:_resolved?) { state[:resolved] }
    future.define_singleton_method(:_pending?) { !state[:resolved] }
  end

  def define_future_type_methods(future, name, state)
    future.define_singleton_method(:_future?) { true }
    future.define_singleton_method(:is_a?) { |k| k == Smolagents::Executors::RactorLazy::ToolFuture || super(k) }
    future.define_singleton_method(:inspect) do
      state[:resolved] ? "#<Future:resolved #{name}>" : "#<Future:pending #{name}>"
    end
  end
end
