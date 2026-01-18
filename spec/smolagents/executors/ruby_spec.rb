RSpec.describe Smolagents::LocalRubyExecutor do
  let(:executor) { described_class.new }

  it_behaves_like "a ruby executor"
  it_behaves_like "an executor"
  it_behaves_like "a safe executor"

  describe "trace_mode", :slow do
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

  describe "retrieval tool guard" do
    let(:wikipedia_tool) do
      instance_double(Smolagents::Tool, name: "wikipedia").tap do |t|
        allow(t).to receive(:call).and_return("Paris is the capital of France")
      end
    end

    let(:final_answer_tool) do
      instance_double(Smolagents::Tool, name: "final_answer").tap do |t|
        allow(t).to receive(:call) { |answer:| raise Smolagents::FinalAnswerException, answer }
      end
    end

    let(:calculate_tool) do
      instance_double(Smolagents::Tool, name: "calculate").tap do |t|
        allow(t).to receive(:call).with(expression: "2 + 2").and_return(4)
      end
    end

    before do
      executor.send_tools({
                            "wikipedia" => wikipedia_tool,
                            "final_answer" => final_answer_tool,
                            "calculate" => calculate_tool
                          })
    end

    it "blocks search + final_answer in same code block" do
      code = <<~RUBY
        result = wikipedia(query: "Paris")
        final_answer(answer: result)
      RUBY

      result = executor.execute(code, language: :ruby)

      expect(result.failure?).to be true
      expect(result.error).to include("Cannot call final_answer in the same step")
      expect(result.error).to include("wikipedia")
    end

    it "allows calculate + final_answer in same code block" do
      code = <<~RUBY
        result = calculate(expression: "2 + 2")
        final_answer(answer: result)
      RUBY

      result = executor.execute(code, language: :ruby)

      expect(result.success?).to be true
      expect(result.output).to eq(4)
      expect(result.is_final_answer).to be true
    end

    it "allows final_answer alone" do
      result = executor.execute("final_answer(answer: 'done')", language: :ruby)

      expect(result.success?).to be true
      expect(result.is_final_answer).to be true
    end

    it "blocks searxng_search + final_answer (matches 'search' pattern)" do
      searxng_tool = instance_double(Smolagents::Tool, name: "searxng_search").tap do |t|
        allow(t).to receive(:call).and_return("Search results here")
      end

      executor.send_tools({
                            "searxng_search" => searxng_tool,
                            "final_answer" => final_answer_tool
                          })

      code = <<~RUBY
        result = searxng_search(query: "Ruby tutorials")
        final_answer(answer: result)
      RUBY

      result = executor.execute(code, language: :ruby)

      expect(result.failure?).to be true
      expect(result.error).to include("Cannot call final_answer in the same step")
      expect(result.error).to include("searxng_search")
    end

    it "blocks web_search + final_answer" do
      web_search_tool = instance_double(Smolagents::Tool, name: "web_search").tap do |t|
        allow(t).to receive(:call).and_return("Search results")
      end

      executor.send_tools({
                            "web_search" => web_search_tool,
                            "final_answer" => final_answer_tool
                          })

      result = executor.execute('final_answer(answer: web_search(query: "test"))', language: :ruby)

      expect(result.failure?).to be true
      expect(result.error).to include("Cannot call final_answer in the same step")
    end
  end
end
