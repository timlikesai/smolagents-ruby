RSpec.describe Smolagents::LocalRubyExecutor do
  let(:executor) { described_class.new }

  it_behaves_like "a ruby executor"

  describe "trace_mode" do
    describe "with :line mode (default)" do
      let(:executor) { described_class.new(trace_mode: :line) }

      it "defaults to :line mode" do
        default_executor = described_class.new
        expect(default_executor.trace_mode).to eq(:line)
      end

      it "executes code correctly" do
        result = executor.execute("[1, 2, 3].sum", language: :ruby)
        expect(result.success?).to be true
        expect(result.output).to eq(6)
      end

      it "prevents infinite loops" do
        result = executor.execute("i = 0; while true; i += 1; end", language: :ruby, timeout: 1)
        expect(result.failure?).to be true
        expect(result.error).to match(/Operation limit exceeded|timeout/)
      end
    end

    describe "with :call mode" do
      let(:executor) { described_class.new(trace_mode: :call) }

      it "stores the trace mode" do
        expect(executor.trace_mode).to eq(:call)
      end

      it "executes simple code correctly" do
        result = executor.execute("2 + 2", language: :ruby)
        expect(result.success?).to be true
        expect(result.output).to eq(4)
      end

      it "executes array operations" do
        result = executor.execute("[1, 2, 3].sum", language: :ruby)
        expect(result.success?).to be true
        expect(result.output).to eq(6)
      end

      it "prevents infinite loops with finer granularity" do
        # With :call mode, the operation limit should be hit sooner
        # since it counts every method/block/C call, not just lines
        result = executor.execute("i = 0; while true; i += 1; end", language: :ruby, timeout: 1)
        expect(result.failure?).to be true
        expect(result.error).to match(/Operation limit exceeded|timeout/)
      end

      it "counts more operations than :line mode for the same code" do
        # This test demonstrates that :call mode fires more frequently
        # :a_call fires for method calls, block calls, and C calls
        line_executor = described_class.new(trace_mode: :line, max_operations: 350)
        call_executor = described_class.new(trace_mode: :call, max_operations: 350)

        code = "100.times { |i| i * 2 }"

        line_result = line_executor.execute(code, language: :ruby)
        call_result = call_executor.execute(code, language: :ruby)

        # :line mode fires ~308 times for this code (succeeds with 350 limit)
        # :call mode fires ~404 times for this code (exceeds 350 limit)
        expect(line_result.success?).to be true

        # :call mode fires for every method/block/C call (:a_call aggregate event),
        # so it uses more operations and will hit the limit
        expect(call_result.failure?).to be true
        expect(call_result.error).to include("Operation limit exceeded")
      end

      it "handles tool calls correctly" do
        tool = double("Tool")
        allow(tool).to receive(:call).with(query: "test").and_return("result")

        executor.send_tools({ "search" => tool })
        result = executor.execute("search(query: 'test')", language: :ruby)

        expect(result.success?).to be true
        expect(result.output).to eq("result")
      end
    end

    describe "with invalid trace_mode" do
      it "raises ArgumentError for invalid mode" do
        expect do
          described_class.new(trace_mode: :invalid)
        end.to raise_error(ArgumentError, /Invalid trace_mode.*:invalid/)
      end

      it "raises ArgumentError for non-symbol mode" do
        expect do
          described_class.new(trace_mode: "line")
        end.to raise_error(ArgumentError, /Invalid trace_mode/)
      end
    end
  end
end
