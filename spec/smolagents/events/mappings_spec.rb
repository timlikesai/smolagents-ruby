require "spec_helper"

RSpec.describe Smolagents::Events::Mappings do
  describe ".resolve" do
    it "returns class as-is when given a class" do
      result = described_class.resolve(Smolagents::Events::StepCompleted)
      expect(result).to eq(Smolagents::Events::StepCompleted)
    end

    it "resolves :tool_call to ToolCallRequested" do
      expect(described_class.resolve(:tool_call)).to eq(Smolagents::Events::ToolCallRequested)
    end

    it "resolves :tool_complete to ToolCallCompleted" do
      expect(described_class.resolve(:tool_complete)).to eq(Smolagents::Events::ToolCallCompleted)
    end

    it "resolves :step_complete to StepCompleted" do
      expect(described_class.resolve(:step_complete)).to eq(Smolagents::Events::StepCompleted)
    end

    it "resolves :task_lifecycle to TaskLifecycle" do
      expect(described_class.resolve(:task_lifecycle)).to eq(Smolagents::Events::TaskLifecycle)
    end

    it "resolves :agent_launch to SubAgentLaunched" do
      expect(described_class.resolve(:agent_launch)).to eq(Smolagents::Events::SubAgentLaunched)
    end

    it "resolves :agent_progress to SubAgentProgress" do
      expect(described_class.resolve(:agent_progress)).to eq(Smolagents::Events::SubAgentProgress)
    end

    it "resolves :agent_complete to SubAgentCompleted" do
      expect(described_class.resolve(:agent_complete)).to eq(Smolagents::Events::SubAgentCompleted)
    end

    it "resolves :error to ErrorOccurred" do
      expect(described_class.resolve(:error)).to eq(Smolagents::Events::ErrorOccurred)
    end

    it "resolves :rate_limit to RateLimitViolated" do
      expect(described_class.resolve(:rate_limit)).to eq(Smolagents::Events::RateLimitViolated)
    end

    it "resolves :retry to RetryRequested" do
      expect(described_class.resolve(:retry)).to eq(Smolagents::Events::RetryRequested)
    end

    it "resolves :failover to FailoverOccurred" do
      expect(described_class.resolve(:failover)).to eq(Smolagents::Events::FailoverOccurred)
    end

    it "resolves :recovery to RecoveryCompleted" do
      expect(described_class.resolve(:recovery)).to eq(Smolagents::Events::RecoveryCompleted)
    end

    it "resolves :control_yielded to ControlYielded" do
      expect(described_class.resolve(:control_yielded)).to eq(Smolagents::Events::ControlYielded)
    end

    it "resolves :control_resumed to ControlResumed" do
      expect(described_class.resolve(:control_resumed)).to eq(Smolagents::Events::ControlResumed)
    end

    it "resolves :tool_isolation to ToolIsolation" do
      expect(described_class.resolve(:tool_isolation)).to eq(Smolagents::Events::ToolIsolation)
    end

    it "resolves :health_check to HealthCheck" do
      expect(described_class.resolve(:health_check)).to eq(Smolagents::Events::HealthCheck)
    end

    it "resolves :model_reliability to ModelReliability" do
      expect(described_class.resolve(:model_reliability)).to eq(Smolagents::Events::ModelReliability)
    end

    it "resolves :circuit_state_changed to CircuitStateChanged" do
      expect(described_class.resolve(:circuit_state_changed)).to eq(Smolagents::Events::CircuitStateChanged)
    end

    it "resolves :rate_limit_violated to RateLimitViolated" do
      expect(described_class.resolve(:rate_limit_violated)).to eq(Smolagents::Events::RateLimitViolated)
    end

    it "resolves :tool_retrying to ToolRetrying" do
      expect(described_class.resolve(:tool_retrying)).to eq(Smolagents::Events::ToolRetrying)
    end

    it "raises ArgumentError for unknown symbol" do
      expect { described_class.resolve(:unknown_event) }
        .to raise_error(ArgumentError, /Unknown event: unknown_event/)
    end

    it "includes valid event names in error message" do
      expect { described_class.resolve(:invalid) }
        .to raise_error(ArgumentError, /tool_call/)
    end
  end

  describe ".valid?" do
    it "returns true for any class" do
      expect(described_class.valid?(String)).to be true
      expect(described_class.valid?(Smolagents::Events::StepCompleted)).to be true
    end

    it "returns true for known symbol names" do
      expect(described_class.valid?(:tool_call)).to be true
      expect(described_class.valid?(:step_complete)).to be true
      expect(described_class.valid?(:error)).to be true
    end

    it "returns false for unknown symbol names" do
      expect(described_class.valid?(:unknown)).to be false
      expect(described_class.valid?(:invalid_event)).to be false
    end
  end

  describe ".names" do
    it "returns all valid event symbol names" do
      names = described_class.names

      expect(names).to include(:tool_call)
      expect(names).to include(:tool_complete)
      expect(names).to include(:step_complete)
      expect(names).to include(:task_lifecycle)
      expect(names).to include(:agent_launch)
      expect(names).to include(:error)
    end

    it "returns symbols" do
      expect(described_class.names).to all(be_a(Symbol))
    end

    it "includes both canonical and alias names" do
      names = described_class.names
      # Canonical names from auto-registration
      expect(names).to include(:tool_call_requested)
      expect(names).to include(:step_completed)
      # Legacy aliases
      expect(names).to include(:tool_call)
      expect(names).to include(:step_complete)
    end
  end

  describe ".classes" do
    it "returns all event classes" do
      classes = described_class.classes

      expect(classes).to include(Smolagents::Events::ToolCallRequested)
      expect(classes).to include(Smolagents::Events::ToolCallCompleted)
      expect(classes).to include(Smolagents::Events::StepCompleted)
      expect(classes).to include(Smolagents::Events::TaskLifecycle)
      expect(classes).to include(Smolagents::Events::ErrorOccurred)
    end

    it "returns same number of classes as canonical names" do
      expect(described_class.classes.size).to eq(described_class.canonical_names.size)
    end

    it "returns only classes" do
      expect(described_class.classes).to all(be_a(Class))
    end
  end

  describe "auto-registration" do
    it "auto-registers events with convention-derived names" do
      expect(described_class.canonical_names).to include(:tool_call_requested)
      expect(described_class.canonical_names).to include(:step_completed)
      expect(described_class.canonical_names).to include(:error_occurred)
    end

    it "legacy aliases resolve to same classes" do
      expect(described_class.resolve(:tool_call)).to eq(described_class.resolve(:tool_call_requested))
      expect(described_class.resolve(:step_complete)).to eq(described_class.resolve(:step_completed))
      expect(described_class.resolve(:error)).to eq(described_class.resolve(:error_occurred))
    end
  end
end
