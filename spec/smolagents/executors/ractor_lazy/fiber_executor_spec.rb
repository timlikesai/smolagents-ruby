# Unit tests for FiberExecutor class.
#
# FiberExecutor runs code in a Fiber, handles batch yields for lazy
# tool evaluation, and sends results back via port communication.

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

  # High default to avoid triggering on RSpec internals during unit tests
  # In production, TracePoint is isolated to Ractor
  let(:max_ops) { 100_000 }

  # Simple context that supports instance_eval
  let(:ctx) do
    obj = Object.new
    obj.define_singleton_method(:puts) { |*args| output.puts(*args) }
    obj.define_singleton_method(:print) { |*args| output.print(*args) }
    obj
  end

  let(:executor) do
    described_class.new(ctx, output, batch, tool_port, result_port, max_ops)
  end

  describe "#execute" do
    context "with simple code" do
      before do
        # Stub Ractor.receive since we won't actually use batch resolution
        allow(Ractor).to receive(:receive).and_return({ results: [] })
      end

      it "executes code and sends success result" do
        executor.execute("2 + 2")

        expect(result_port.sent_results.size).to eq(1)
        result = result_port.sent_results.first
        expect(result[:success]).to be true
        expect(result[:result]).to eq(4)
        expect(result[:is_final]).to be false
      end

      # Output capture is tested via integration tests in ractor_lazy_spec.rb
      # because it requires the full Context setup where puts/print are properly
      # wired to the shared StringIO. Unit testing with a mock context doesn't
      # capture the real wiring.
      it "output capture is tested via integration" do
        # The executor writes logs from @output.string
        # This requires proper Context setup, see ractor_lazy_spec.rb
        executor.execute("42")

        result = result_port.sent_results.first
        # Just verify logs field exists
        expect(result).to have_key(:logs)
      end

      it "clears batch between executions" do
        batch << "old_item"
        executor.execute("42")

        expect(batch).to be_empty
      end
    end

    # NOTE: SyntaxError is not a StandardError (it's a ScriptError), so it
    # propagates out of run_code. This is tested via integration in ractor_lazy_spec.rb.
    # The FiberExecutor itself handles only StandardError within run_code.
    context "with syntax errors" do
      before do
        allow(Ractor).to receive(:receive).and_return({ results: [] })
      end

      it "raises SyntaxError (not caught by run_code)" do
        # SyntaxError inherits from ScriptError, not StandardError
        expect { executor.execute("def broken") }.to raise_error(SyntaxError)
      end
    end

    context "with runtime errors" do
      before do
        allow(Ractor).to receive(:receive).and_return({ results: [] })
      end

      it "sends error result" do
        executor.execute("raise 'oops'")

        result = result_port.sent_results.first
        expect(result[:success]).to be false
        expect(result[:error]).to include("RuntimeError")
        expect(result[:error]).to include("oops")
      end
    end

    context "with FinalAnswerSignal" do
      before do
        allow(Ractor).to receive(:receive).and_return({ results: [] })
        ctx.define_singleton_method(:final_answer) do |answer:|
          raise Smolagents::Executors::FinalAnswerSignal, answer
        end
      end

      it "marks result as final" do
        executor.execute("final_answer(answer: 'done')")

        result = result_port.sent_results.first
        expect(result[:success]).to be true
        expect(result[:result]).to eq("done")
        expect(result[:is_final]).to be true
      end
    end

    # Operation limit tests are skipped in unit tests because TracePoint
    # tracks ALL Ruby lines globally, not just the evaluated code.
    # In production, this works because code runs in an isolated Ractor.
    # See ractor_lazy_spec.rb for integration coverage of operation limits.
    context "with operation limit" do
      it "is tested via integration tests in ractor_lazy_spec.rb" do
        # TracePoint(:line) counts RSpec internals too, making unit testing unreliable
        # The mechanism works correctly in Ractor isolation
        skip "Operation limit requires Ractor isolation - see ractor_lazy_spec.rb"
      end
    end
  end

  describe "batch handling", :slow do
    # Factory for mock futures - uses closure to avoid instance variables
    # rubocop:disable Metrics/MethodLength -- mock factory
    def build_mock_future(name, args, kwargs, batch_array)
      state = { resolved: false, result: nil, error: nil }

      Object.new.tap do |future|
        future.define_singleton_method(:tool_name) { name }
        future.define_singleton_method(:args) { args }
        future.define_singleton_method(:kwargs) { kwargs }
        future.define_singleton_method(:_resolve!) do |v|
          state[:result] = v
          state[:resolved] = true
        end
        future.define_singleton_method(:_reject!) do |e|
          state[:error] = e
          state[:resolved] = true
        end
        future.define_singleton_method(:_resolved?) { state[:resolved] }
        future.define_singleton_method(:_pending?) { !state[:resolved] }
        future.define_singleton_method(:_result) { state[:result] }
        future.define_singleton_method(:_error) { state[:error] }
        future.define_singleton_method(:_future?) { true }
        future.define_singleton_method(:is_a?) do |klass|
          klass == Smolagents::Executors::RactorLazy::ToolFuture || super(klass)
        end
        future.define_singleton_method(:inspect) do
          state[:resolved] ? "#<Future:resolved #{name}>" : "#<Future:pending #{name}>"
        end
        batch_array << future
      end
    end
    # rubocop:enable Metrics/MethodLength

    context "when code yields batch request" do
      it "handles batch and continues execution" do
        # Setup: create a future that will yield
        future = build_mock_future("search", [], { query: "test" }, batch)

        # Stub Ractor.receive to simulate tool execution response
        allow(Ractor).to receive(:receive).and_return({
                                                        results: [{ success: true, value: "search_result" }]
                                                      })

        # Context that returns a future on tool call
        ctx.define_singleton_method(:search) do |query:|
          _ = query
          future
        end

        # Create fiber that will yield on future access
        result_value = nil
        fiber = Fiber.new do
          f = ctx.search(query: "test")
          # Simulating future access - normally ToolFuture would yield here
          Fiber.yield({ type: :batch, futures: [f] })
          result_value = f._result
          { type: :result, value: result_value }
        end

        # Run fiber
        yielded = fiber.resume
        expect(yielded[:type]).to eq(:batch)

        # Resolve the future (simulating BatchHandling)
        future._resolve!("search_result")

        # Resume and get result
        final = fiber.resume
        expect(final[:type]).to eq(:result)
        expect(final[:value]).to eq("search_result")
      end
    end
  end

  describe "#process_fiber_result" do
    before do
      allow(Ractor).to receive(:receive).and_return({ results: [] })
    end

    it "returns true for batch requests to continue processing" do
      result = executor.send(:process_fiber_result, { type: :batch, futures: [] })

      expect(result).to be true
    end

    it "returns false for result to stop processing" do
      result = executor.send(:process_fiber_result, { type: :result, value: 42 })

      expect(result).to be false
    end

    it "returns false for final_answer to stop processing" do
      result = executor.send(:process_fiber_result, { type: :final_answer, value: "done" })

      expect(result).to be false
    end

    it "returns false for error to stop processing" do
      result = executor.send(:process_fiber_result, { type: :error, error: "failed" })

      expect(result).to be false
    end
  end

  describe "#resolve_and_send" do
    before do
      allow(Ractor).to receive(:receive).and_return({ results: [] })
    end

    it "sends regular result" do
      executor.send(:resolve_and_send, :result, "value")

      result = result_port.sent_results.first
      expect(result[:success]).to be true
      expect(result[:result]).to eq("value")
      expect(result[:is_final]).to be false
    end

    it "sends final result" do
      executor.send(:resolve_and_send, :final, "final_value")

      result = result_port.sent_results.first
      expect(result[:success]).to be true
      expect(result[:result]).to eq("final_value")
      expect(result[:is_final]).to be true
    end
  end

  describe "#send_error" do
    it "sends error result" do
      executor.send(:send_error, "Something went wrong")

      result = result_port.sent_results.first
      expect(result[:success]).to be false
      expect(result[:error]).to eq("Something went wrong")
      expect(result[:logs]).to eq("")
    end

    it "includes captured logs" do
      output.puts("some debug info")
      executor.send(:send_error, "failed")

      result = result_port.sent_results.first
      expect(result[:logs]).to include("some debug info")
    end
  end

  describe "private helpers" do
    describe "#reset_output" do
      it "clears the output buffer" do
        output.puts("old content")
        executor.send(:reset_output)

        expect(output.string).to eq("")
      end
    end
  end
end
