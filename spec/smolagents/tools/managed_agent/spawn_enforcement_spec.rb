RSpec.describe Smolagents::Tools::ManagedAgentTool do
  describe "Spawn enforcement functionality" do
    let(:mock_agent) do
      double(
        "agent",
        run: double("result", success?: true, output: "output"),
        respond_to?: false,
        tools: { search: double, web: double },
        max_steps: 20
      )
    end

    let(:tool) do
      described_class.new(
        agent: mock_agent,
        name: "test_agent",
        description: "Test agent"
      )
    end

    before do
      allow(tool).to receive(:emit)
    end

    describe "spawn policy attributes" do
      it "initializes with nil policy and context" do
        expect(tool.spawn_policy).to be_nil
        expect(tool.spawn_context).to be_nil
      end

      it "allows setting spawn_policy" do
        policy = double("policy")
        tool.spawn_policy = policy

        expect(tool.spawn_policy).to eq(policy)
      end

      it "allows setting spawn_context" do
        context = double("context")
        tool.spawn_context = context

        expect(tool.spawn_context).to eq(context)
      end
    end

    describe "#validate_spawn_policy!" do
      context "when policy enforcement disabled" do
        it "returns without validation when no policy" do
          tool.spawn_policy = nil
          tool.spawn_context = nil

          expect { tool.send(:validate_spawn_policy!) }.not_to raise_error
        end

        it "returns without validation when no context" do
          tool.spawn_policy = double("policy")
          tool.spawn_context = nil

          expect { tool.send(:validate_spawn_policy!) }.not_to raise_error
        end
      end

      context "when policy enforcement enabled" do
        it "validates spawn policy" do
          policy = double("policy")
          context = double("context")
          validation = double("validation", denied?: false)

          tool.spawn_policy = policy
          tool.spawn_context = context

          allow(policy).to receive(:validate).and_return(validation)

          expect { tool.send(:validate_spawn_policy!) }.not_to raise_error
          expect(policy).to have_received(:validate)
        end

        it "raises SpawnError when validation denied" do
          policy = double("policy")
          context = double("context")
          validation = double(
            "validation",
            denied?: true,
            violations: [double(to_s: "Tool not allowed")],
            to_error_message: "Spawn denied"
          )

          tool.spawn_policy = policy
          tool.spawn_context = context

          allow(policy).to receive(:validate).and_return(validation)
          allow(tool).to receive(:emit_spawn_restricted)

          expect { tool.send(:validate_spawn_policy!) }
            .to raise_error(Smolagents::Errors::SpawnError)
        end
      end
    end

    describe "#policy_enforcement_enabled?" do
      it "returns false when both policy and context are nil" do
        tool.spawn_policy = nil
        tool.spawn_context = nil

        expect(tool.send(:policy_enforcement_enabled?)).to be_falsey
      end

      it "returns false when policy is nil" do
        tool.spawn_policy = nil
        tool.spawn_context = double

        expect(tool.send(:policy_enforcement_enabled?)).to be_falsey
      end

      it "returns false when context is nil" do
        tool.spawn_policy = double
        tool.spawn_context = nil

        expect(tool.send(:policy_enforcement_enabled?)).to be_falsey
      end

      it "returns true when both are set" do
        tool.spawn_policy = double
        tool.spawn_context = double

        expect(tool.send(:policy_enforcement_enabled?)).to be_truthy
      end
    end

    describe "#perform_policy_validation" do
      it "validates with agent tool names and max steps" do
        policy = double("policy")
        context = double("context")
        validation = double("validation", denied?: false)

        tool.spawn_policy = policy
        tool.spawn_context = context

        allow(policy).to receive(:validate).and_return(validation)

        tool.send(:perform_policy_validation)

        expect(policy).to have_received(:validate).with(
          context,
          hash_including(
            requested_tools: %i[search web],
            requested_steps: 20
          )
        )
      end
    end

    describe "#agent_tool_names" do
      it "returns agent tool names as symbols" do
        tool_names = tool.send(:agent_tool_names)

        expect(tool_names).to include(:search, :web)
        expect(tool_names.all?(Symbol)).to be true
      end
    end

    describe "#raise_spawn_error" do
      it "emits spawn restricted event" do
        validation = double(
          violations: [double(to_s: "Max depth exceeded")],
          to_error_message: "Spawn denied due to depth"
        )

        allow(tool).to receive(:emit_spawn_restricted)

        expect { tool.send(:raise_spawn_error, validation) }
          .to raise_error(Smolagents::Errors::SpawnError)

        expect(tool).to have_received(:emit_spawn_restricted)
      end

      it "includes agent name and reason in error" do
        validation = double(
          violations: [double(to_s: "Tool not available")],
          to_error_message: "Spawn validation failed"
        )

        allow(tool).to receive(:emit_spawn_restricted)

        begin
          tool.send(:raise_spawn_error, validation)
        rescue Smolagents::Errors::SpawnError => e
          # The message comes from validation.to_error_message
          expect(e.message).to include("Spawn validation failed")
          # Agent name and reason are stored as error attributes
          expect(e.agent_name).to eq("test_agent")
          expect(e.reason).to eq("Tool not available")
        end
      end
    end

    describe "#emit_spawn_restricted" do
      it "emits SpawnRestricted event with violation details" do
        validation = double(
          violations: [double(to_s: "Depth limit exceeded")]
        )

        tool.spawn_context = double(depth: 3, path_string: "parent > test_agent")

        tool.send(:emit_spawn_restricted, validation)

        expect(tool).to have_received(:emit)
      end

      it "handles call when spawn_context is set" do
        validation = double(violations: [double(to_s: "Some violation")])

        tool.spawn_context = double(depth: 1, path_string: "root")

        # Should emit without error when context is set
        expect { tool.send(:emit_spawn_restricted, validation) }.not_to raise_error
        expect(tool).to have_received(:emit)
      end
    end

    describe "#child_spawn_context" do
      context "when no spawn context" do
        it "returns nil" do
          tool.spawn_context = nil

          result = tool.send(:child_spawn_context)

          expect(result).to be_nil
        end
      end

      context "when spawn context exists" do
        it "creates descending context for child" do
          parent_context = double("context")
          child_context = double("child_context")

          tool.spawn_context = parent_context
          allow(parent_context).to receive(:descend).and_return(child_context)

          result = tool.send(:child_spawn_context)

          expect(parent_context).to have_received(:descend).with(
            hash_including(
              steps_allocated: 20,
              child_tools: %i[search web],
              agent_name: "test_agent"
            )
          )
          expect(result).to eq(child_context)
        end
      end
    end

    describe "#child_spawn_policy" do
      context "when policy doesn't inherit restrictions" do
        it "returns the same policy" do
          policy = double("policy", inherit_restrictions: false)
          tool.spawn_policy = policy

          result = tool.send(:child_spawn_policy)

          expect(result).to eq(policy)
        end
      end

      context "when policy inherits restrictions" do
        it "creates child policy with inherited restrictions" do
          policy = double("policy", inherit_restrictions: true)
          context = double("context", parent_tools: [:search], remaining_steps: 10)
          child_policy = double("child_policy")

          tool.spawn_policy = policy
          tool.spawn_context = context

          allow(policy).to receive(:child_policy).and_return(child_policy)

          result = tool.send(:child_spawn_policy)

          expect(policy).to have_received(:child_policy).with(
            hash_including(
              parent_tools: [:search],
              remaining_steps: 10
            )
          )
          expect(result).to eq(child_policy)
        end
      end
    end

    describe "#propagate_spawn_restrictions" do
      context "when agent doesn't respond to spawn_policy=" do
        it "returns early" do
          tool.spawn_policy = double("policy")
          allow(mock_agent).to receive(:respond_to?).with(:spawn_policy=).and_return(false)

          expect { tool.send(:propagate_spawn_restrictions) }.not_to raise_error
        end
      end

      context "when agent responds to spawn_policy=" do
        it "sets child policy on agent" do
          agent = double("agent")
          allow(agent).to receive(:respond_to?).with(:spawn_policy=).and_return(true)
          allow(agent).to receive(:spawn_policy=)
          allow(agent).to receive(:respond_to?).with(:spawn_context=).and_return(false)

          tool = described_class.new(
            agent:,
            name: "test_agent",
            description: "Test"
          )

          policy = double("policy", inherit_restrictions: false)
          tool.spawn_policy = policy

          tool.send(:propagate_spawn_restrictions)

          expect(agent).to have_received(:spawn_policy=)
        end

        it "sets child context when agent supports it" do
          agent = double("agent")
          allow(agent).to receive(:respond_to?).with(:spawn_policy=).and_return(true)
          allow(agent).to receive(:spawn_policy=)
          allow(agent).to receive(:respond_to?).with(:spawn_context=).and_return(true)
          allow(agent).to receive(:spawn_context=)
          allow(agent).to receive_messages(tools: { search: double }, max_steps: 20)

          tool = described_class.new(
            agent:,
            name: "test_agent",
            description: "Test"
          )

          policy = double("policy", inherit_restrictions: false)
          context = double("context", descend: double)

          tool.spawn_policy = policy
          tool.spawn_context = context

          tool.send(:propagate_spawn_restrictions)

          expect(agent).to have_received(:spawn_context=)
        end
      end
    end
  end
end
