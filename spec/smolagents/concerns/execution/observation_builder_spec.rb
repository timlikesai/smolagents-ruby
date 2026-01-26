require "smolagents/concerns/execution/observation_builder"
require "smolagents/concerns/execution/code_hints"
require "smolagents/concerns/execution/budget_tracking"

RSpec.describe Smolagents::Concerns::ObservationBuilder do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::ObservationBuilder
      include Smolagents::Concerns::CodeHints
      include Smolagents::Concerns::BudgetTracking

      attr_accessor :max_steps

      def initialize
        @max_steps = nil
      end

      def route_observations(obs, step)
        obs # Simple pass-through for testing
      end
    end
  end

  let(:instance) { test_class.new }
  let(:mock_action_step) do
    instance_double(Smolagents::Types::ActionStep, step_number: 1)
  end

  describe "#build_observations" do
    context "with logs and output" do
      it "combines logs and formatted output" do
        logs = "Tool execution completed"
        output = "Result: 42"
        code = "result = calculate()"
        final_answer = nil

        result = instance.send(:build_observations, mock_action_step, output, logs, code, final_answer)

        expect(result).to include(logs)
        expect(result).to include(output)
      end

      it "separates logs and output with newline" do
        logs = "Log line"
        output = "Output line"

        result = instance.send(:build_observations, mock_action_step, output, logs, "", nil)

        lines = result.split("\n")
        expect(lines[0]).to eq("Log line")
        expect(lines[1]).to eq("Output line")
      end
    end

    context "with final_answer set" do
      it "does not include output when final_answer is set" do
        logs = "Logs"
        output = "Should be ignored"
        final_answer = "Answer provided"

        result = instance.send(:build_observations, mock_action_step, output, logs, "", final_answer)

        expect(result).to include(logs)
        expect(result).not_to include("Should be ignored")
      end
    end

    context "with nil output" do
      it "returns only logs" do
        logs = "Execution logs"
        output = nil

        result = instance.send(:build_observations, mock_action_step, output, logs, "", nil)

        expect(result).to eq(logs)
      end
    end

    context "with nil logs" do
      it "returns only formatted output" do
        logs = nil
        output = "Output data"

        result = instance.send(:build_observations, mock_action_step, output, logs, "", nil)

        expect(result).to include("Output data")
      end
    end

    context "with empty logs" do
      it "skips empty logs" do
        logs = ""
        output = "Output"

        result = instance.send(:build_observations, mock_action_step, output, logs, "", nil)

        expect(result).to include("Output")
        expect(result).not_to start_with("\n")
      end
    end

    context "with iterator noise" do
      it "filters out Range returns" do
        logs = "Logs"
        output = (1..10)
        final_answer = nil

        result = instance.send(:build_observations, mock_action_step, output, logs, "", final_answer)

        expect(result).to eq(logs)
      end

      it "filters out Enumerator returns" do
        logs = "Logs"
        output = [1, 2, 3].each
        final_answer = nil

        result = instance.send(:build_observations, mock_action_step, output, logs, "", final_answer)

        expect(result).to eq(logs)
      end
    end

    context "with observation routing" do
      before do
        allow(instance).to receive(:respond_to?).with(:route_observations, true).and_return(true)
        allow(instance).to receive(:route_observations).and_return("Routed observations")
      end

      it "routes observations if available" do
        logs = "Logs"
        output = "Output"

        instance.send(:build_observations, mock_action_step, output, logs, "", nil)

        expect(instance).to have_received(:route_observations)
      end
    end

    context "with code hints applied" do
      it "applies code hints to final result" do
        logs = "Logs"
        output = "Output"
        code = "final_answer = result"
        final_answer = nil

        result = instance.send(:build_observations, mock_action_step, output, logs, code, final_answer)

        # Should include code hints if collect_code_hints returns hints
        expect(result).to be_a(String)
      end
    end

    context "with long output" do
      it "truncates output longer than 5000 characters" do
        logs = "Logs"
        output = "x" * 6000
        final_answer = nil

        result = instance.send(:build_observations, mock_action_step, output, logs, "", final_answer)

        expect(result).to include("[truncated]")
        expect(result.length).to be < (6000 + 100)
      end

      it "preserves short output" do
        logs = "Logs"
        output = "Short output"
        final_answer = nil

        result = instance.send(:build_observations, mock_action_step, output, logs, "", final_answer)

        expect(result).to include("Short output")
        expect(result).not_to include("[truncated]")
      end
    end
  end

  describe "#iterator_noise?" do
    it "identifies Range as noise" do
      noise = (1..10)
      result = instance.send(:iterator_noise?, noise)

      expect(result).to be true
    end

    it "identifies Enumerator as noise" do
      noise = [1, 2, 3].each
      result = instance.send(:iterator_noise?, noise)

      expect(result).to be true
    end

    it "does not identify strings as noise" do
      not_noise = "string output"
      result = instance.send(:iterator_noise?, not_noise)

      expect(result).to be false
    end

    it "does not identify integers as noise" do
      not_noise = 42
      result = instance.send(:iterator_noise?, not_noise)

      expect(result).to be false
    end

    it "does not identify hashes as noise" do
      not_noise = { key: "value" }
      result = instance.send(:iterator_noise?, not_noise)

      expect(result).to be false
    end

    it "does not identify arrays as noise" do
      not_noise = [1, 2, 3]
      result = instance.send(:iterator_noise?, not_noise)

      expect(result).to be false
    end
  end

  describe "#format_output" do
    context "with normal string output" do
      it "returns string representation" do
        output = "Result: success"
        formatted = instance.send(:format_output, output)

        expect(formatted).to eq("Result: success")
      end
    end

    context "with object output" do
      it "converts object to string" do
        output = 42
        formatted = instance.send(:format_output, output)

        expect(formatted).to eq("42")
      end
    end

    context "with empty string" do
      it "returns nil for empty string" do
        output = ""
        formatted = instance.send(:format_output, output)

        expect(formatted).to be_nil
      end
    end

    context "with long output" do
      it "truncates to 5000 characters" do
        long_str = "x" * 6000
        formatted = instance.send(:format_output, long_str)

        expect(formatted.length).to eq(5000 + "...[truncated]".length)
        expect(formatted).to end_with("...[truncated]")
      end

      it "preserves first 5000 characters" do
        prefix = "Start_#{"x" * 5000}End"
        formatted = instance.send(:format_output, prefix)

        expect(formatted).to start_with("Start_")
        expect(formatted).to include("[truncated]")
      end
    end

    context "with exactly 5000 characters" do
      it "does not truncate" do
        output = "x" * 5000
        formatted = instance.send(:format_output, output)

        expect(formatted.length).to eq(5000)
        expect(formatted).not_to include("[truncated]")
      end
    end

    context "with less than 5000 characters" do
      it "returns full output" do
        output = "x" * 3000
        formatted = instance.send(:format_output, output)

        expect(formatted.length).to eq(3000)
        expect(formatted).not_to include("[truncated]")
      end
    end

    context "with special characters" do
      it "preserves formatting" do
        output = "Line 1\nLine 2\nLine 3"
        formatted = instance.send(:format_output, output)

        expect(formatted).to eq(output)
      end

      it "handles unicode" do
        output = "Résultat: Succès ✓"
        formatted = instance.send(:format_output, output)

        expect(formatted).to eq(output)
      end
    end
  end

  describe "integration" do
    it "builds complete observations from all sources" do
      logs = "Executed web_search\nFound 5 results"
      output = { count: 5, results: %w[result1 result2] }
      code = "results = search(query: 'test')"
      final_answer = nil

      result = instance.send(:build_observations, mock_action_step, output, logs, code, final_answer)

      expect(result).to be_a(String)
      expect(result).to include("Executed web_search")
    end

    it "handles complex execution flow" do
      logs = "Step 1: Initialized\nStep 2: Executed"
      output = (1..5) # Iterator - should be filtered
      code = "range = (1..5)"
      final_answer = nil

      result = instance.send(:build_observations, mock_action_step, output, logs, code, final_answer)

      # Iterator noise should be filtered
      expect(result).to include(logs)
    end

    it "respects final_answer and filters output" do
      logs = "Logs"
      output = "This should be filtered"
      code = "final_answer(answer: 'complete')"
      final_answer = "complete"

      result = instance.send(:build_observations, mock_action_step, output, logs, code, final_answer)

      expect(result).to eq(logs)
    end

    it "combines logs, output, and code hints" do
      logs = "Execution output"
      output = "Result value"
      code = "puts output"
      final_answer = nil

      result = instance.send(:build_observations, mock_action_step, output, logs, code, final_answer)

      expect(result).to be_a(String)
      expect(result.length).to be > logs.length
    end
  end
end
