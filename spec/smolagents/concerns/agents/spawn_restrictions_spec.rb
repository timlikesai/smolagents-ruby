require "spec_helper"

RSpec.describe Smolagents::Concerns::Agents::SpawnRestrictions do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::Agents::SpawnRestrictions

      attr_accessor :emitted_events

      def initialize(spawn_policy: nil, spawn_context: nil, max_steps: 10, tools: {})
        @emitted_events = []
        initialize_spawn_restrictions(
          spawn_policy:,
          spawn_context:,
          max_steps:,
          tools:
        )
      end

      def emit(event)
        @emitted_events << event
      end
    end
  end

  describe "#initialize_spawn_restrictions" do
    it "creates disabled policy when none provided" do
      instance = test_class.new

      expect(instance.spawn_policy).to be_a(Smolagents::Security::SpawnPolicy)
      expect(instance.spawn_policy.disabled?).to be true
    end

    it "creates root context when none provided" do
      instance = test_class.new(max_steps: 20, tools: { search: double, web: double })

      expect(instance.spawn_context).to be_a(Smolagents::Security::SpawnContext)
      expect(instance.spawn_context.depth).to eq(0)
      expect(instance.spawn_context.remaining_steps).to eq(20)
    end

    it "extracts tool names from hash" do
      instance = test_class.new(tools: { search: double, web: double })

      expect(instance.spawn_context.parent_tools).to eq(%i[search web])
    end

    it "uses provided policy" do
      policy = Smolagents::Security::SpawnPolicy.create(max_depth: 5)
      instance = test_class.new(spawn_policy: policy)

      expect(instance.spawn_policy.max_depth).to eq(5)
    end

    it "uses provided context" do
      context = Smolagents::Security::SpawnContext.create(depth: 2)
      instance = test_class.new(spawn_context: context)

      expect(instance.spawn_context.depth).to eq(2)
    end
  end

  describe "#validate_spawn!" do
    context "with disabled policy" do
      it "allows spawn" do
        instance = test_class.new

        result = instance.send(:validate_spawn!, requested_tools: [:search])

        expect(result.allowed?).to be true
      end
    end

    context "with enabled policy" do
      let(:policy) do
        Smolagents::Security::SpawnPolicy.create(
          max_depth: 2,
          allowed_tools: %i[search final_answer],
          max_steps_per_agent: 10
        )
      end

      let(:context) do
        Smolagents::Security::SpawnContext.create(
          depth: 1,
          remaining_steps: 20,
          parent_tools: %i[search final_answer]
        )
      end

      it "allows valid spawn" do
        instance = test_class.new(spawn_policy: policy, spawn_context: context)

        result = instance.send(:validate_spawn!, requested_tools: [:search])

        expect(result.allowed?).to be true
      end

      it "raises SpawnError when denied" do
        # Create a context at depth 2, which exceeds max_depth of 2
        at_limit_context = Smolagents::Security::SpawnContext.create(
          depth: 2,
          remaining_steps: 20,
          parent_tools: %i[search final_answer]
        )
        instance = test_class.new(spawn_policy: policy, spawn_context: at_limit_context)

        expect do
          instance.send(:validate_spawn!)
        end.to raise_error(Smolagents::Errors::SpawnError)
      end

      it "emits SpawnRestricted event when denied" do
        at_limit_context = Smolagents::Security::SpawnContext.create(
          depth: 2,
          remaining_steps: 20,
          parent_tools: %i[search final_answer]
        )
        instance = test_class.new(spawn_policy: policy, spawn_context: at_limit_context)

        begin
          instance.send(:validate_spawn!)
        rescue Smolagents::Errors::SpawnError
          # Expected
        end

        expect(instance.emitted_events.size).to eq(1)
        expect(instance.emitted_events.first).to be_a(Smolagents::Events::SpawnRestricted)
      end
    end
  end

  describe "#spawn_allowed?" do
    let(:policy) do
      Smolagents::Security::SpawnPolicy.create(
        max_depth: 2,
        allowed_tools: [:final_answer],
        max_steps_per_agent: 10
      )
    end

    let(:context) do
      Smolagents::Security::SpawnContext.create(
        depth: 1,
        remaining_steps: 20,
        parent_tools: [:final_answer]
      )
    end

    it "returns true when spawn would be allowed" do
      instance = test_class.new(spawn_policy: policy, spawn_context: context)

      expect(instance.send(:spawn_allowed?, requested_tools: [:final_answer])).to be true
    end

    it "returns false when spawn would be denied" do
      instance = test_class.new(spawn_policy: policy, spawn_context: context)

      expect(instance.send(:spawn_allowed?, requested_tools: [:unauthorized])).to be false
    end

    it "does not raise when denied" do
      instance = test_class.new(spawn_policy: policy, spawn_context: context)

      expect { instance.send(:spawn_allowed?, requested_tools: [:unauthorized]) }.not_to raise_error
    end
  end

  describe "#child_spawn_context" do
    let(:context) do
      Smolagents::Security::SpawnContext.create(
        depth: 1,
        remaining_steps: 20,
        parent_tools: %i[search final_answer],
        spawn_path: %w[root parent]
      )
    end

    it "creates child context with incremented depth" do
      instance = test_class.new(spawn_context: context)

      child = instance.send(:child_spawn_context, agent_name: "child", steps: 10)

      expect(child.depth).to eq(2)
    end

    it "sets allocated steps" do
      instance = test_class.new(spawn_context: context)

      child = instance.send(:child_spawn_context, agent_name: "child", steps: 8)

      expect(child.remaining_steps).to eq(8)
    end

    it "appends agent name to path" do
      instance = test_class.new(spawn_context: context)

      child = instance.send(:child_spawn_context, agent_name: "researcher", steps: 10)

      expect(child.spawn_path).to eq(%w[root parent researcher])
    end

    it "uses custom tools when provided" do
      instance = test_class.new(spawn_context: context)

      child = instance.send(:child_spawn_context, agent_name: "child", steps: 10, tools: [:final_answer])

      expect(child.parent_tools).to eq([:final_answer])
    end
  end

  describe "#child_spawn_policy" do
    it "returns restricted policy with inheritance enabled" do
      policy = Smolagents::Security::SpawnPolicy.create(
        allowed_tools: %i[search web final_answer],
        max_steps_per_agent: 15,
        inherit_restrictions: true
      )
      context = Smolagents::Security::SpawnContext.create(
        remaining_steps: 10,
        parent_tools: %i[search final_answer]
      )
      instance = test_class.new(spawn_policy: policy, spawn_context: context)

      child_policy = instance.send(:child_spawn_policy)

      expect(child_policy.allowed_tools).to eq(%i[search final_answer])
      expect(child_policy.max_steps_per_agent).to eq(10)
    end

    it "returns original policy when inheritance disabled" do
      policy = Smolagents::Security::SpawnPolicy.create(
        inherit_restrictions: false
      )
      instance = test_class.new(spawn_policy: policy)

      expect(instance.send(:child_spawn_policy)).to eq(policy)
    end
  end

  describe "#spawn_depth" do
    it "returns context depth" do
      context = Smolagents::Security::SpawnContext.create(depth: 3)
      instance = test_class.new(spawn_context: context)

      expect(instance.send(:spawn_depth)).to eq(3)
    end

    it "returns 0 when no context" do
      instance = test_class.new

      expect(instance.send(:spawn_depth)).to eq(0)
    end
  end

  describe "#spawn_path" do
    it "returns context path string" do
      context = Smolagents::Security::SpawnContext.create(spawn_path: %w[root child grandchild])
      instance = test_class.new(spawn_context: context)

      expect(instance.send(:spawn_path)).to eq("root > child > grandchild")
    end
  end

  describe "#root_agent?" do
    it "returns true at depth 0" do
      context = Smolagents::Security::SpawnContext.create(depth: 0)
      instance = test_class.new(spawn_context: context)

      expect(instance.send(:root_agent?)).to be true
    end

    it "returns false at depth > 0" do
      context = Smolagents::Security::SpawnContext.create(depth: 1)
      instance = test_class.new(spawn_context: context)

      expect(instance.send(:root_agent?)).to be false
    end
  end

  describe "#remaining_spawn_budget" do
    it "returns remaining steps from context" do
      context = Smolagents::Security::SpawnContext.create(remaining_steps: 42)
      instance = test_class.new(spawn_context: context)

      expect(instance.send(:remaining_spawn_budget)).to eq(42)
    end
  end

  describe "#consume_spawn_budget" do
    it "decreases remaining steps" do
      context = Smolagents::Security::SpawnContext.create(remaining_steps: 20)
      instance = test_class.new(spawn_context: context)

      instance.send(:consume_spawn_budget, 5)

      expect(instance.spawn_context.remaining_steps).to eq(15)
    end

    it "does not go below 0" do
      context = Smolagents::Security::SpawnContext.create(remaining_steps: 5)
      instance = test_class.new(spawn_context: context)

      instance.send(:consume_spawn_budget, 10)

      expect(instance.spawn_context.remaining_steps).to eq(0)
    end
  end
end
