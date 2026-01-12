RSpec.describe Smolagents::AgentResult do
  let(:timing) { Smolagents::Timing.new(start_time: 1.0, end_time: 2.5) }
  let(:token_usage) { Smolagents::TokenUsage.new(input_tokens: 100, output_tokens: 50) }

  describe "initialization" do
    it "creates with minimal arguments" do
      result = described_class.new(agent_name: "test_agent", output: "test output")

      expect(result.agent_name).to eq("test_agent")
      expect(result.output).to eq("test output")
      expect(result.outcome).to eq(Smolagents::Outcome::SUCCESS)
      expect(result.error).to be_nil
      expect(result.steps_taken).to eq(0)
    end

    it "creates with all arguments" do
      error = StandardError.new("test error")

      result = described_class.new(
        agent_name: "full_agent",
        output: "result",
        outcome: Smolagents::Outcome::ERROR,
        error: error,
        timing: timing,
        token_usage: token_usage,
        steps_taken: 5,
        trace_id: "abc-123"
      )

      expect(result.agent_name).to eq("full_agent")
      expect(result.outcome).to eq(Smolagents::Outcome::ERROR)
      expect(result.error).to eq(error)
      expect(result.steps_taken).to eq(5)
      expect(result.trace_id).to eq("abc-123")
    end
  end

  describe "outcome predicates" do
    it "returns true for success?" do
      result = described_class.new(agent_name: "a", output: "o", outcome: Smolagents::Outcome::SUCCESS)
      expect(result.success?).to be true
      expect(result.failure?).to be false
    end

    it "returns true for partial?" do
      result = described_class.new(agent_name: "a", output: "o", outcome: Smolagents::Outcome::PARTIAL)
      expect(result.partial?).to be true
    end

    it "returns true for failure?" do
      result = described_class.new(agent_name: "a", output: "o", outcome: Smolagents::Outcome::FAILURE)
      expect(result.failure?).to be true
    end

    it "returns true for error?" do
      result = described_class.new(agent_name: "a", output: "o", outcome: Smolagents::Outcome::ERROR)
      expect(result.error?).to be true
    end
  end

  describe "computed properties" do
    it "returns duration_seconds from timing" do
      result = described_class.new(agent_name: "a", output: "o", timing: timing)
      expect(result.duration_seconds).to eq(timing.duration)
    end

    it "returns 0 for duration_seconds without timing" do
      result = described_class.new(agent_name: "a", output: "o")
      expect(result.duration_seconds).to eq(0.0)
    end

    it "returns input_tokens from token_usage" do
      result = described_class.new(agent_name: "a", output: "o", token_usage: token_usage)
      expect(result.input_tokens).to eq(100)
    end

    it "returns output_tokens from token_usage" do
      result = described_class.new(agent_name: "a", output: "o", token_usage: token_usage)
      expect(result.output_tokens).to eq(50)
    end

    it "returns total_tokens" do
      result = described_class.new(agent_name: "a", output: "o", token_usage: token_usage)
      expect(result.total_tokens).to eq(150)
    end

    it "returns 0 for token counts without token_usage" do
      result = described_class.new(agent_name: "a", output: "o")
      expect(result.input_tokens).to eq(0)
      expect(result.output_tokens).to eq(0)
      expect(result.total_tokens).to eq(0)
    end
  end

  describe "#to_h" do
    it "returns hash representation" do
      result = described_class.new(
        agent_name: "test",
        output: "result",
        outcome: Smolagents::Outcome::SUCCESS,
        timing: timing,
        token_usage: token_usage,
        steps_taken: 3,
        trace_id: "trace-1"
      )

      hash = result.to_h

      expect(hash[:agent_name]).to eq("test")
      expect(hash[:output]).to eq("result")
      expect(hash[:outcome]).to eq(:success)
      expect(hash[:steps_taken]).to eq(3)
      expect(hash[:trace_id]).to eq("trace-1")
      expect(hash[:timing]).to be_a(Hash)
      expect(hash[:token_usage]).to be_a(Hash)
    end

    it "extracts error message from exception" do
      error = StandardError.new("something went wrong")
      result = described_class.new(agent_name: "a", output: "o", error: error)

      expect(result.to_h[:error]).to eq("something went wrong")
    end

    it "excludes nil values" do
      result = described_class.new(agent_name: "a", output: "o")

      expect(result.to_h.keys).not_to include(:error, :timing, :token_usage, :trace_id)
    end
  end

  describe ".from_run_result" do
    let(:run_result) do
      instance_double(
        Smolagents::RunResult,
        output: "agent output",
        timing: timing,
        token_usage: token_usage,
        steps: [{}, {}, {}],
        state: :success,
        success?: true
      )
    end

    it "creates AgentResult from RunResult" do
      result = described_class.from_run_result(run_result, agent_name: "my_agent")

      expect(result.agent_name).to eq("my_agent")
      expect(result.output).to eq("agent output")
      expect(result.outcome).to eq(Smolagents::Outcome::SUCCESS)
      expect(result.steps_taken).to eq(3)
      expect(result.timing).to eq(timing)
      expect(result.token_usage).to eq(token_usage)
    end

    it "includes trace_id if provided" do
      result = described_class.from_run_result(run_result, agent_name: "a", trace_id: "trace-123")

      expect(result.trace_id).to eq("trace-123")
    end
  end
end
