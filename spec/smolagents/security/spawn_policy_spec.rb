require "spec_helper"

RSpec.describe Smolagents::Security::SpawnPolicy do
  describe ".create" do
    it "creates a policy with default values" do
      policy = described_class.create

      expect(policy.max_depth).to eq(2)
      expect(policy.allowed_tools).to eq([:final_answer])
      expect(policy.max_steps_per_agent).to eq(10)
      expect(policy.inherit_restrictions).to be true
    end

    it "accepts custom values" do
      policy = described_class.create(
        max_depth: 3,
        allowed_tools: %i[search web],
        max_steps_per_agent: 5,
        inherit_restrictions: false
      )

      expect(policy.max_depth).to eq(3)
      expect(policy.allowed_tools).to eq(%i[search web])
      expect(policy.max_steps_per_agent).to eq(5)
      expect(policy.inherit_restrictions).to be false
    end

    it "normalizes tool names to symbols" do
      policy = described_class.create(allowed_tools: %w[search web])

      expect(policy.allowed_tools).to eq(%i[search web])
    end

    it "freezes allowed_tools array" do
      policy = described_class.create(allowed_tools: [:search])

      expect(policy.allowed_tools).to be_frozen
    end
  end

  describe ".disabled" do
    it "creates a policy that prevents all spawning" do
      policy = described_class.disabled

      expect(policy.max_depth).to eq(0)
      expect(policy.allowed_tools).to eq([])
      expect(policy.max_steps_per_agent).to eq(0)
      expect(policy.disabled?).to be true
    end
  end

  describe ".permissive" do
    it "creates a policy with minimal restrictions" do
      policy = described_class.permissive

      expect(policy.max_depth).to eq(10)
      expect(policy.allowed_tools).to eq(:any)
      expect(policy.max_steps_per_agent).to eq(100)
      expect(policy.inherit_restrictions).to be false
    end

    it "accepts custom tools" do
      policy = described_class.permissive(tools: %i[search web])

      expect(policy.allowed_tools).to eq(%i[search web])
    end
  end

  describe "#enabled?" do
    it "returns true when max_depth > 0" do
      policy = described_class.create(max_depth: 1)

      expect(policy.enabled?).to be true
    end

    it "returns false when max_depth is 0" do
      policy = described_class.disabled

      expect(policy.enabled?).to be false
    end
  end

  describe "#disabled?" do
    it "returns true when max_depth is 0" do
      policy = described_class.disabled

      expect(policy.disabled?).to be true
    end

    it "returns false when max_depth > 0" do
      policy = described_class.create(max_depth: 1)

      expect(policy.disabled?).to be false
    end
  end

  describe "#any_tool_allowed?" do
    it "returns true when allowed_tools is :any" do
      policy = described_class.permissive

      expect(policy.any_tool_allowed?).to be true
    end

    it "returns false when allowed_tools is an array" do
      policy = described_class.create(allowed_tools: [:search])

      expect(policy.any_tool_allowed?).to be false
    end
  end

  describe "#validate" do
    let(:context) do
      Smolagents::Security::SpawnContext.create(
        depth: 1,
        remaining_steps: 20,
        parent_tools: %i[search web final_answer]
      )
    end

    context "when spawn is allowed" do
      it "returns allowed validation" do
        policy = described_class.create(
          max_depth: 3,
          allowed_tools: %i[search final_answer],
          max_steps_per_agent: 10
        )

        result = policy.validate(context, requested_tools: [:search], requested_steps: 5)

        expect(result.allowed?).to be true
        expect(result.violations).to be_empty
      end
    end

    context "when depth is exceeded" do
      it "returns denied validation" do
        policy = described_class.create(max_depth: 1)

        result = policy.validate(context, requested_tools: [:final_answer])

        expect(result.denied?).to be true
        expect(result.violations.first.type).to eq(:depth_exceeded)
      end

      it "includes depth info in violation" do
        policy = described_class.create(max_depth: 1)

        result = policy.validate(context)

        expect(result.violations.first.to_s).to include("depth 1")
        expect(result.violations.first.to_s).to include("max is 1")
      end
    end

    context "when tool is unauthorized" do
      it "returns denied validation" do
        policy = described_class.create(
          max_depth: 5,
          allowed_tools: [:final_answer]
        )

        result = policy.validate(context, requested_tools: [:search])

        expect(result.denied?).to be true
        expect(result.violations.first.type).to eq(:unauthorized_tool)
      end

      it "includes tool name in violation" do
        policy = described_class.create(allowed_tools: [:final_answer])

        result = policy.validate(context, requested_tools: [:dangerous_tool])

        expect(result.violations.first.to_s).to include("dangerous_tool")
      end

      it "reports multiple unauthorized tools" do
        policy = described_class.create(allowed_tools: [:final_answer])

        result = policy.validate(context, requested_tools: %i[search web])

        expect(result.violations.size).to eq(2)
      end
    end

    context "when steps are exceeded" do
      it "returns denied when requested steps exceed max per agent" do
        policy = described_class.create(max_steps_per_agent: 5)

        result = policy.validate(context, requested_tools: [:final_answer], requested_steps: 10)

        expect(result.denied?).to be true
        expect(result.violations.first.type).to eq(:steps_exceeded)
      end

      it "returns denied when requested steps exceed remaining budget" do
        limited_context = Smolagents::Security::SpawnContext.create(
          depth: 0,
          remaining_steps: 3,
          parent_tools: [:final_answer]
        )
        policy = described_class.create(max_steps_per_agent: 10)

        result = policy.validate(limited_context, requested_tools: [:final_answer], requested_steps: 5)

        expect(result.denied?).to be true
      end

      it "includes step details in violation" do
        policy = described_class.create(max_steps_per_agent: 5)

        result = policy.validate(context, requested_steps: 10)

        violation_str = result.violations.first.to_s
        expect(violation_str).to include("requested 10")
        expect(violation_str).to include("max per agent 5")
      end
    end

    context "with permissive policy" do
      it "allows any tools" do
        policy = described_class.permissive

        result = policy.validate(context, requested_tools: %i[any_tool another_tool])

        expect(result.allowed?).to be true
      end
    end

    context "with multiple violations" do
      it "reports all violations" do
        policy = described_class.create(
          max_depth: 1,
          allowed_tools: [:final_answer],
          max_steps_per_agent: 5
        )

        result = policy.validate(context, requested_tools: [:search], requested_steps: 10)

        expect(result.violations.size).to eq(3)
        types = result.violations.map(&:type)
        expect(types).to include(:depth_exceeded)
        expect(types).to include(:unauthorized_tool)
        expect(types).to include(:steps_exceeded)
      end
    end
  end

  describe "#child_policy" do
    it "restricts allowed_tools to intersection with parent" do
      policy = described_class.create(allowed_tools: %i[search web final_answer])

      child = policy.child_policy(
        parent_tools: %i[search final_answer],
        remaining_steps: 20
      )

      expect(child.allowed_tools).to eq(%i[search final_answer])
    end

    it "restricts max_steps_per_agent to min of policy and remaining" do
      policy = described_class.create(max_steps_per_agent: 10)

      child = policy.child_policy(parent_tools: [:final_answer], remaining_steps: 5)

      expect(child.max_steps_per_agent).to eq(5)
    end

    it "does not modify when inherit_restrictions is false" do
      policy = described_class.create(
        allowed_tools: [:search],
        max_steps_per_agent: 10,
        inherit_restrictions: false
      )

      child = policy.child_policy(parent_tools: [:final_answer], remaining_steps: 5)

      expect(child).to eq(policy)
    end
  end
end

RSpec.describe Smolagents::Security::SpawnContext do
  describe ".create" do
    it "creates a context with default values" do
      context = described_class.create

      expect(context.depth).to eq(0)
      expect(context.remaining_steps).to eq(100)
      expect(context.parent_tools).to eq([])
      expect(context.spawn_path).to eq([])
    end

    it "accepts custom values" do
      context = described_class.create(
        depth: 2,
        remaining_steps: 15,
        parent_tools: %i[search web],
        spawn_path: %w[root child]
      )

      expect(context.depth).to eq(2)
      expect(context.remaining_steps).to eq(15)
      expect(context.parent_tools).to eq(%i[search web])
      expect(context.spawn_path).to eq(%w[root child])
    end

    it "normalizes tool names to symbols" do
      context = described_class.create(parent_tools: %w[search web])

      expect(context.parent_tools).to eq(%i[search web])
    end

    it "freezes arrays" do
      context = described_class.create(parent_tools: [:search], spawn_path: ["root"])

      expect(context.parent_tools).to be_frozen
      expect(context.spawn_path).to be_frozen
    end
  end

  describe ".root" do
    it "creates a root context for a top-level agent" do
      context = described_class.root(
        max_steps: 50,
        tools: %i[search final_answer],
        agent_name: "coordinator"
      )

      expect(context.depth).to eq(0)
      expect(context.remaining_steps).to eq(50)
      expect(context.parent_tools).to eq(%i[search final_answer])
      expect(context.spawn_path).to eq(["coordinator"])
    end

    it "uses 'root' as default agent name" do
      context = described_class.root(max_steps: 10, tools: [])

      expect(context.spawn_path).to eq(["root"])
    end
  end

  describe "#descend" do
    let(:parent) do
      described_class.create(
        depth: 1,
        remaining_steps: 20,
        parent_tools: %i[search web final_answer],
        spawn_path: %w[root parent]
      )
    end

    it "creates a child context with incremented depth" do
      child = parent.descend(steps_allocated: 10, agent_name: "child")

      expect(child.depth).to eq(2)
    end

    it "sets remaining_steps to allocated amount" do
      child = parent.descend(steps_allocated: 8, agent_name: "child")

      expect(child.remaining_steps).to eq(8)
    end

    it "inherits parent_tools by default" do
      child = parent.descend(steps_allocated: 10, agent_name: "child")

      expect(child.parent_tools).to eq(parent.parent_tools)
    end

    it "accepts custom child_tools" do
      child = parent.descend(
        steps_allocated: 10,
        child_tools: %i[search final_answer],
        agent_name: "child"
      )

      expect(child.parent_tools).to eq(%i[search final_answer])
    end

    it "appends agent_name to spawn_path" do
      child = parent.descend(steps_allocated: 10, agent_name: "researcher")

      expect(child.spawn_path).to eq(%w[root parent researcher])
    end

    it "uses 'child' as default agent_name" do
      child = parent.descend(steps_allocated: 10)

      expect(child.spawn_path).to eq(%w[root parent child])
    end
  end

  describe "#root?" do
    it "returns true for depth 0" do
      context = described_class.create(depth: 0)

      expect(context.root?).to be true
    end

    it "returns false for depth > 0" do
      context = described_class.create(depth: 1)

      expect(context.root?).to be false
    end
  end

  describe "#parent_name" do
    it "returns the second-to-last element of spawn_path" do
      context = described_class.create(spawn_path: %w[root parent child])

      expect(context.parent_name).to eq("parent")
    end

    it "returns nil for root context" do
      context = described_class.create(spawn_path: ["root"])

      expect(context.parent_name).to be_nil
    end
  end

  describe "#current_name" do
    it "returns the last element of spawn_path" do
      context = described_class.create(spawn_path: %w[root parent child])

      expect(context.current_name).to eq("child")
    end
  end

  describe "#path_string" do
    it "joins spawn_path with ' > '" do
      context = described_class.create(spawn_path: %w[root parent child])

      expect(context.path_string).to eq("root > parent > child")
    end
  end

  describe "#deconstruct_keys" do
    it "supports pattern matching" do
      context = described_class.create(depth: 2, remaining_steps: 10)

      case context
      in { depth: d, remaining_steps: steps }
        expect(d).to eq(2)
        expect(steps).to eq(10)
      end
    end
  end
end

RSpec.describe Smolagents::Security::SpawnValidation do
  describe "#allowed?" do
    it "returns true when allowed" do
      result = described_class.new(allowed: true, violations: [])

      expect(result.allowed?).to be true
    end

    it "returns false when denied" do
      result = described_class.new(allowed: false, violations: [])

      expect(result.denied?).to be true
    end
  end

  describe "#to_error_message" do
    it "returns nil when allowed" do
      result = described_class.new(allowed: true, violations: [])

      expect(result.to_error_message).to be_nil
    end

    it "formats violations as error message" do
      violations = [
        Smolagents::Security::SpawnViolation.depth_exceeded(current: 2, max: 1),
        Smolagents::Security::SpawnViolation.unauthorized_tool(:search)
      ]
      result = described_class.new(allowed: false, violations:)

      message = result.to_error_message
      expect(message).to include("Spawn denied")
      expect(message).to include("depth")
      expect(message).to include("search")
    end
  end
end

RSpec.describe Smolagents::Security::SpawnViolation do
  describe ".depth_exceeded" do
    it "creates a depth violation" do
      violation = described_class.depth_exceeded(current: 3, max: 2)

      expect(violation.type).to eq(:depth_exceeded)
      expect(violation.detail).to eq({ current: 3, max: 2 })
    end

    it "formats as string" do
      violation = described_class.depth_exceeded(current: 3, max: 2)

      expect(violation.to_s).to eq("Depth limit exceeded: at depth 3, max is 2")
    end
  end

  describe ".unauthorized_tool" do
    it "creates a tool violation" do
      violation = described_class.unauthorized_tool(:dangerous_tool)

      expect(violation.type).to eq(:unauthorized_tool)
      expect(violation.detail).to eq({ tool: :dangerous_tool })
    end

    it "formats as string" do
      violation = described_class.unauthorized_tool(:search)

      expect(violation.to_s).to eq("Tool :search not allowed for sub-agents")
    end
  end

  describe ".steps_exceeded" do
    it "creates a steps violation" do
      violation = described_class.steps_exceeded(
        requested: 15,
        max_per_agent: 10,
        remaining: 8
      )

      expect(violation.type).to eq(:steps_exceeded)
      expect(violation.detail).to eq({ requested: 15, max_per_agent: 10, remaining: 8 })
    end

    it "formats as string" do
      violation = described_class.steps_exceeded(
        requested: 15,
        max_per_agent: 10,
        remaining: 8
      )

      str = violation.to_s
      expect(str).to include("requested 15")
      expect(str).to include("max per agent 10")
      expect(str).to include("remaining budget 8")
    end
  end

  describe "#deconstruct_keys" do
    it "supports pattern matching" do
      violation = described_class.depth_exceeded(current: 3, max: 2)

      case violation
      in { type: :depth_exceeded, detail: { current: c, max: m } }
        expect(c).to eq(3)
        expect(m).to eq(2)
      end
    end
  end
end
