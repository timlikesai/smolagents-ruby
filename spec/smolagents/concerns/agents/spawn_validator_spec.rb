require "smolagents/concerns/agents/spawn_validator"

RSpec.describe Smolagents::Concerns::Agents::SpawnValidator do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::Agents::SpawnValidator

      attr_accessor :spawn_policy, :spawn_context

      def initialize(spawn_policy = nil, spawn_context = nil)
        @spawn_policy = spawn_policy
        @spawn_context = spawn_context
      end

      def emit(event)
        # No-op for testing
      end

      def emitting?
        false
      end
    end
  end

  let(:mock_policy) do
    instance_double(Smolagents::Security::SpawnPolicy, disabled?: false)
  end

  let(:mock_context) do
    instance_double(Smolagents::Security::SpawnContext,
                    parent_tools: [:search],
                    remaining_steps: 5,
                    depth: 1,
                    path_string: "root > child")
  end

  let(:instance) { test_class.new(mock_policy, mock_context) }

  describe "#validate_spawn!" do
    context "when spawn policy is disabled" do
      before do
        instance.spawn_policy = nil
      end

      it "allows spawn without validation" do
        result = instance.send(:validate_spawn!, requested_tools: [:search], requested_steps: 5)
        expect(result.allowed?).to be true
      end
    end

    context "when spawn policy is present and enabled" do
      let(:allowed_validation) do
        instance_double(Smolagents::Security::SpawnValidation,
                        denied?: false,
                        allowed?: true)
      end

      before do
        allow(mock_policy).to receive(:validate).and_return(allowed_validation)
      end

      it "performs validation" do
        instance.send(:validate_spawn!, requested_tools: [:search], requested_steps: 5)
        expect(mock_policy).to have_received(:validate).with(
          mock_context,
          requested_tools: [:search],
          requested_steps: 5
        )
      end

      it "returns validation when allowed" do
        result = instance.send(:validate_spawn!, requested_tools: [:search], requested_steps: 5)
        expect(result).to eq(allowed_validation)
      end
    end

    context "when spawn is denied" do
      let(:denied_validation) do
        violation = instance_double(Smolagents::Security::SpawnViolation,
                                    to_s: "Depth limit exceeded")
        instance_double(Smolagents::Security::SpawnValidation,
                        denied?: true,
                        allowed?: false,
                        to_error_message: "Spawn denied: Depth limit exceeded",
                        violations: [violation])
      end

      before do
        allow(mock_policy).to receive(:validate).and_return(denied_validation)
      end

      it "raises SpawnError" do
        expect do
          instance.send(:validate_spawn!, requested_tools: [:search], requested_steps: 5)
        end.to raise_error(Smolagents::Errors::SpawnError)
      end

      it "includes error details in exception" do
        expect do
          instance.send(:validate_spawn!, requested_tools: [:search], requested_steps: 5)
        end.to raise_error(Smolagents::Errors::SpawnError) do |error|
          expect(error.reason).to include("Depth limit exceeded")
        end
      end
    end
  end

  describe "#spawn_allowed?" do
    context "when policy is disabled" do
      before do
        instance.spawn_policy = nil
      end

      it "returns true" do
        expect(instance.send(:spawn_allowed?, requested_tools: [:search])).to be true
      end
    end

    context "when validation passes" do
      let(:allowed_validation) do
        instance_double(Smolagents::Security::SpawnValidation, allowed?: true)
      end

      before do
        allow(mock_policy).to receive(:validate).and_return(allowed_validation)
      end

      it "returns true without raising" do
        result = instance.send(:spawn_allowed?, requested_tools: [:search])
        expect(result).to be true
      end
    end

    context "when validation fails" do
      let(:denied_validation) do
        instance_double(Smolagents::Security::SpawnValidation, allowed?: false)
      end

      before do
        allow(mock_policy).to receive(:validate).and_return(denied_validation)
      end

      it "returns false without raising" do
        result = instance.send(:spawn_allowed?, requested_tools: [:search])
        expect(result).to be false
      end
    end
  end

  describe "#child_spawn_context" do
    it "creates a child context" do
      child_ctx = instance_double(Smolagents::Security::SpawnContext)
      allow(mock_context).to receive(:descend).and_return(child_ctx)

      instance.send(:child_spawn_context, agent_name: "child_agent", steps: 5)

      expect(mock_context).to have_received(:descend).with(
        steps_allocated: 5,
        child_tools: [:search],
        agent_name: "child_agent"
      )
    end

    context "with tools specified" do
      it "uses specified tools" do
        child_ctx = instance_double(Smolagents::Security::SpawnContext)
        allow(mock_context).to receive(:descend).and_return(child_ctx)

        instance.send(:child_spawn_context,
                      agent_name: "child",
                      steps: 5,
                      tools: [:custom_tool])

        expect(mock_context).to have_received(:descend).with(
          steps_allocated: 5,
          child_tools: [:custom_tool],
          agent_name: "child"
        )
      end
    end

    context "without tools specified" do
      it "uses parent tools" do
        child_ctx = instance_double(Smolagents::Security::SpawnContext)
        allow(mock_context).to receive(:descend).and_return(child_ctx)

        instance.send(:child_spawn_context,
                      agent_name: "child",
                      steps: 5)

        expect(mock_context).to have_received(:descend).with(
          steps_allocated: 5,
          child_tools: [:search],
          agent_name: "child"
        )
      end
    end
  end

  describe "#child_spawn_policy" do
    context "when policy does not inherit restrictions" do
      before do
        allow(mock_policy).to receive(:inherit_restrictions).and_return(false)
      end

      it "returns parent policy" do
        result = instance.send(:child_spawn_policy)
        expect(result).to eq(mock_policy)
      end
    end

    context "when policy inherits restrictions" do
      let(:child_policy) do
        instance_double(Smolagents::Security::SpawnPolicy)
      end

      before do
        allow(mock_policy).to receive_messages(inherit_restrictions: true, child_policy:)
      end

      it "creates a child policy" do
        instance.send(:child_spawn_policy)
        expect(mock_policy).to have_received(:child_policy).with(
          parent_tools: [:search],
          remaining_steps: 5
        )
      end

      it "returns the child policy" do
        result = instance.send(:child_spawn_policy)
        expect(result).to eq(child_policy)
      end
    end
  end

  describe "#allow_spawn" do
    it "returns allowed validation" do
      result = instance.send(:allow_spawn)
      expect(result).to be_a(Smolagents::Security::SpawnValidation)
      expect(result.allowed?).to be true
      expect(result.violations).to be_empty
    end
  end

  describe "#emit_spawn_restricted" do
    let(:violation) do
      instance_double(Smolagents::Security::SpawnViolation,
                      to_s: "Tool not allowed")
    end

    let(:validation) do
      instance_double(Smolagents::Security::SpawnValidation,
                      violations: [violation])
    end

    context "when Events::SpawnRestricted is defined" do
      it "emits spawn restricted event" do
        mock_event_class = double("SpawnRestrictedClass")
        mock_event = double("SpawnRestrictedEvent")
        stub_const("Smolagents::Events::SpawnRestricted", mock_event_class)
        allow(mock_event_class).to receive(:create).and_return(mock_event)

        allow(instance).to receive(:emit)

        instance.send(:emit_spawn_restricted, validation)

        expect(mock_event_class).to have_received(:create).with(
          depth: 1,
          violations: ["Tool not allowed"],
          spawn_path: "root > child"
        )
      end
    end

    context "when Events::SpawnRestricted is not defined" do
      it "does not raise an error" do
        expect do
          instance.send(:emit_spawn_restricted, validation)
        end.not_to raise_error
      end
    end
  end

  describe "spawn validation flow" do
    let(:allowed_validation) do
      instance_double(Smolagents::Security::SpawnValidation,
                      denied?: false,
                      allowed?: true)
    end

    before do
      allow(mock_policy).to receive(:validate).and_return(allowed_validation)
    end

    it "validates spawn request and returns result" do
      result = instance.send(:validate_spawn!,
                             requested_tools: %i[search file_write],
                             requested_steps: 3)

      expect(result.allowed?).to be true
    end

    it "checks both tools and steps" do
      instance.send(:validate_spawn!,
                    requested_tools: [:search],
                    requested_steps: 5)

      expect(mock_policy).to have_received(:validate).with(
        mock_context,
        requested_tools: [:search],
        requested_steps: 5
      )
    end
  end
end
