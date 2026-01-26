RSpec.describe Smolagents::Executors::Executor::ResultBuilder do
  let(:test_executor) do
    Class.new(Smolagents::Executor) do
      include Smolagents::Executors::Executor::ResultBuilder

      # rubocop:disable Lint/MissingSuper -- test double doesn't need parent initialization
      def initialize(max_output_length = 1024)
        @max_output_length = max_output_length
      end
      # rubocop:enable Lint/MissingSuper

      def supports?(language)
        language == :ruby
      end
    end
  end

  describe "#build_result" do
    let(:executor) { test_executor.new }

    it "creates ExecutionResult with output" do
      result = executor.send(:build_result, 42, "")

      expect(result).to be_a(Smolagents::Executors::ExecutionResult)
      expect(result.output).to eq(42)
    end

    it "includes logs in result" do
      logs = "Processing...\nDone."
      result = executor.send(:build_result, "data", logs)

      expect(result.logs).to eq(logs)
    end

    it "sets error when provided" do
      result = executor.send(:build_result, nil, "", error: "Something failed")

      expect(result.error).to eq("Something failed")
      expect(result.failure?).to be true
    end

    it "marks final_answer when flag is true" do
      result = executor.send(:build_result, "answer", "", is_final: true)

      expect(result.final_answer).to be true
    end

    it "defaults final_answer to false" do
      result = executor.send(:build_result, "result", "")

      expect(result.final_answer).to be false
    end

    it "handles complex output values" do
      output = { data: [1, 2, 3], status: "ok" }
      result = executor.send(:build_result, output, "")

      expect(result.output).to eq(output)
    end

    it "combines error flag with is_final" do
      result = executor.send(:build_result, nil, "", error: "failed", is_final: true)

      expect(result.failure?).to be true
      expect(result.final_answer).to be true
    end
  end

  describe "log truncation" do
    describe "with default max_output_length" do
      let(:executor) { test_executor.new(1024) }

      it "truncates logs exceeding max length" do
        long_logs = "x" * 2000
        result = executor.send(:build_result, "output", long_logs)

        expect(result.logs.bytesize).to be <= 1024
      end

      it "preserves logs under max length" do
        short_logs = "Processing complete"
        result = executor.send(:build_result, "output", short_logs)

        expect(result.logs).to eq(short_logs)
      end

      it "truncates at byte boundaries" do
        logs = ("a" * 1024) + ("b" * 100)
        result = executor.send(:build_result, "output", logs)

        expect(result.logs.bytesize).to eq(1024)
      end

      it "keeps first N bytes on truncation" do
        logs = "START#{"x" * 2000}END"
        result = executor.send(:build_result, "output", logs)

        expect(result.logs).to start_with("START")
        expect(result.logs).not_to include("END")
      end
    end

    describe "with custom max_output_length" do
      let(:executor) { test_executor.new(256) }

      it "respects custom limit" do
        long_logs = "y" * 1000
        result = executor.send(:build_result, "output", long_logs)

        expect(result.logs.bytesize).to be <= 256
      end

      it "handles small limits" do
        executor_small = test_executor.new(10)
        logs = "This is a longer message"
        result = executor_small.send(:build_result, "output", logs)

        expect(result.logs.bytesize).to be <= 10
      end
    end

    describe "with very large limits" do
      let(:executor) { test_executor.new(10_000_000) }

      it "preserves entire log" do
        logs = "Long logs " * 1000
        result = executor.send(:build_result, "output", logs)

        expect(result.logs).to eq(logs)
      end
    end

    describe "with zero limit" do
      let(:executor) { test_executor.new(0) }

      it "truncates to empty string" do
        logs = "This will be truncated"
        result = executor.send(:build_result, "output", logs)

        expect(result.logs).to eq("")
      end
    end

    describe "log truncation edge cases" do
      let(:executor) { test_executor.new(10) }

      it "handles empty logs" do
        result = executor.send(:build_result, "output", "")

        expect(result.logs).to eq("")
      end

      it "handles nil logs" do
        result = executor.send(:build_result, "output", nil)

        expect(result.logs).to eq("")
      end

      it "handles non-string logs" do
        result = executor.send(:build_result, "output", 12_345)

        # Will be converted to string and truncated
        expect(result.logs.bytesize).to be <= 10
      end

      it "handles multibyte characters" do
        # "你好" = 6 bytes in UTF-8
        logs = "你好世界" * 10
        result = executor.send(:build_result, "output", logs)

        expect(result.logs.bytesize).to be <= 10
      end

      it "handles special characters" do
        logs = "\n\t\r" * 1000
        result = executor.send(:build_result, "output", logs)

        expect(result.logs.bytesize).to be <= 1024
      end
    end
  end

  describe "typical workflows" do
    let(:executor) { test_executor.new }

    it "builds successful execution result" do
      result = executor.send(:build_result, 100, "Calculation complete")

      expect(result.success?).to be true
      expect(result.output).to eq(100)
      expect(result.logs).to eq("Calculation complete")
    end

    it "builds failed execution result" do
      result = executor.send(:build_result, nil, "Error log", error: "NameError: undefined variable")

      expect(result.failure?).to be true
      expect(result.error).to eq("NameError: undefined variable")
    end

    it "builds final answer result" do
      result = executor.send(:build_result, "The answer is 42", "", is_final: true)

      expect(result.success?).to be true
      expect(result.final_answer).to be true
    end

    it "combines multiple aspects" do
      output = { computed: 42, explanation: "Found via search" }
      logs = "Step 1: searched\nStep 2: computed\nStep 3: verified"
      result = executor.send(
        :build_result,
        output,
        logs,
        is_final: true
      )

      expect(result.success?).to be true
      expect(result.output).to eq(output)
      expect(result.logs).to include("Step 1")
      expect(result.final_answer).to be true
    end
  end

  describe "integration with ExecutionResult" do
    let(:executor) { test_executor.new }

    it "creates valid ExecutionResult through factory" do
      result = executor.send(:build_result, "done", "logs")

      expect(result).to be_a(Smolagents::Executors::ExecutionResult)
      expect(result.success?).to be true
    end

    it "result is immutable Data instance" do
      result = executor.send(:build_result, 42, "")

      # Data.define classes don't have setter methods
      expect { result.output = 100 }.to raise_error(NoMethodError)
    end
  end

  describe "max_output_length initialization" do
    it "accepts custom max_output_length" do
      executor = test_executor.new(2048)
      expect(executor.instance_variable_get(:@max_output_length)).to eq(2048)
    end

    it "defaults to reasonable value" do
      executor = test_executor.new(1024)
      expect(executor.instance_variable_get(:@max_output_length)).to eq(1024)
    end

    it "can be very large" do
      executor = test_executor.new(1_000_000)
      large_logs = "x" * 500_000
      result = executor.send(:build_result, "output", large_logs)

      expect(result.logs.bytesize).to eq(500_000)
    end

    it "can be very small" do
      executor = test_executor.new(1)
      logs = "hello world"
      result = executor.send(:build_result, "output", logs)

      expect(result.logs.bytesize).to be <= 1
    end
  end

  describe "performance considerations" do
    let(:executor) { test_executor.new(1024) }

    it "truncates large logs efficiently", :slow do
      large_logs = "x" * 10_000_000 # 10MB - large allocation justifies :slow tag
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = executor.send(:build_result, "output", large_logs)
      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

      expect(result.logs.bytesize).to be <= 1024
      expect(duration).to be < 1 # Should be fast
    end

    it "handles multiple builds efficiently" do
      100.times do |i|
        logs = "Log entry #{i}: " + ("x" * 1000)
        result = executor.send(:build_result, i, logs)
        expect(result.logs.bytesize).to be <= 1024
      end
    end
  end

  describe "included functionality" do
    it "is included in executor and provides attr_reader" do
      executor = test_executor.new(512)

      # Included concern should have set up attr_reader
      expect(executor.max_output_length).to eq(512)
    end
  end
end
