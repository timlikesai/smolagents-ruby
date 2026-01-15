RSpec.describe Smolagents::LocalRubyExecutor do
  let(:executor) { described_class.new }

  it_behaves_like "a ruby executor"

  describe "trace_mode" do
    describe "with :line mode" do
      let(:executor) { described_class.new(trace_mode: :line) }

      it "has :call as default mode" do
        default_executor = described_class.new
        expect(default_executor.trace_mode).to eq(:call)
      end

      it "executes code correctly" do
        result = executor.execute("[1, 2, 3].sum", language: :ruby)
        expect(result.success?).to be true
        expect(result.output).to eq(6)
      end

      it "enforces operation limit" do
        limited = described_class.new(trace_mode: :line, max_operations: 50)
        result = limited.execute("100.times { |i| i }", language: :ruby)
        expect(result.failure?).to be true
        expect(result.error).to include("Operation limit exceeded")
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

      it "enforces operation limit with finer granularity" do
        limited = described_class.new(trace_mode: :call, max_operations: 50)
        result = limited.execute("100.times { |i| i }", language: :ruby)
        expect(result.failure?).to be true
        expect(result.error).to include("Operation limit exceeded")
      end

      it "counts more operations than :line mode for the same code" do
        # :call mode fires for method/block/C calls, :line mode only for lines
        # Limit 10 allows line mode (6 ops) to succeed but call mode (12 ops) to fail
        line_executor = described_class.new(trace_mode: :line, max_operations: 10)
        call_executor = described_class.new(trace_mode: :call, max_operations: 10)

        # Method chain that shows clear difference between modes
        code = "[1,2,3,4,5].map { |x| x.to_s }.join"

        line_result = line_executor.execute(code, language: :ruby)
        call_result = call_executor.execute(code, language: :ruby)

        # :line mode uses fewer operations for the same code
        expect(line_result.success?).to be true

        # :call mode uses more operations and hits the limit
        expect(call_result.failure?).to be true
        expect(call_result.error).to include("Operation limit exceeded")
      end

      it "handles tool calls correctly" do
        tool = instance_double(Smolagents::Tool)
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
