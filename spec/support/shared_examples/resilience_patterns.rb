# Shared examples for resilience patterns.
#
# Usage:
#   it_behaves_like "a resilient operation" do
#     let(:operation) { -> { subject.execute } }
#     let(:expected_retries) { 3 }
#   end
#
#   it_behaves_like "a budget-respecting operation" do
#     let(:run_agent) { -> { agent.run("task") } }
#     let(:budget_limit) { 5 }
#     let(:steps_executed) { -> { agent.step_count } }
#   end

RSpec.shared_examples "a resilient operation" do
  it "completes successfully on first attempt" do
    attempts = 0
    result = operation.call do
      attempts += 1
      "ok"
    end
    expect(result).to eq("ok")
    expect(attempts).to eq(1)
  end

  it "retries on transient failure and succeeds" do
    attempts = 0
    result = operation.call do
      attempts += 1
      raise "transient" if attempts < 2

      "recovered"
    end
    expect(result).to eq("recovered")
    expect(attempts).to eq(2)
  end

  it "respects maximum retry count" do
    attempts = 0
    expect do
      operation.call do
        attempts += 1
        raise "persistent failure"
      end
    end.to raise_error(RuntimeError, "persistent failure")

    expect(attempts).to be <= expected_retries + 1
  end

  it "tracks the number of attempts made" do
    attempts = 0
    operation.call do
      attempts += 1
      "done"
    end
    expect(attempts).to be >= 1
  end
end

RSpec.shared_examples "a budget-respecting operation" do
  it "terminates when budget limit is reached" do
    run_agent.call
    expect(steps_executed.call).to be <= budget_limit
  end

  it "does not exceed the configured limit" do
    run_agent.call
    expect(steps_executed.call).not_to be > budget_limit
  end

  it "returns a result even at budget exhaustion" do
    result = run_agent.call
    expect(result).not_to be_nil
  end
end
