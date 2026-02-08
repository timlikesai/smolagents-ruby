# Shared examples for error recovery.
#
# Usage:
#   it_behaves_like "error recovery" do
#     let(:failing_operation) { -> { raise error_class, "boom" } }
#     let(:recovery_operation) { -> { recovery_result } }
#     let(:error_class) { RuntimeError }
#     let(:recovery_result) { "recovered" }
#   end
#
#   it_behaves_like "graceful degradation" do
#     let(:failing_operation) { -> { raise RuntimeError, "fatal" } }
#     let(:degraded_result) { Smolagents::Types::AgentResult.failure("degraded") }
#     let(:run_with_recovery) { -> { subject.run_with_fallback } }
#   end

RSpec.shared_examples "error recovery" do
  it "catches the expected error class" do
    expect { failing_operation.call }.to raise_error(error_class)
  end

  it "classifies the error" do
    result = Smolagents::Concerns::FailureClassification.classify(
      error_class.new("test")
    )
    expect(result).to respond_to(:category)
    expect(result.category).to be_a(Symbol)
  end

  it "produces a successful result after recovery" do
    result = recovery_operation.call
    expect(result).to eq(recovery_result)
  end
end

RSpec.shared_examples "graceful degradation" do
  it "does not raise when recovery fails" do
    expect { run_with_recovery.call }.not_to raise_error
  end

  it "returns a degraded result instead of crashing" do
    result = run_with_recovery.call
    expect(result).not_to be_nil
  end

  it "returns the expected degraded result" do
    result = run_with_recovery.call
    expect(result).to eq(degraded_result)
  end
end
