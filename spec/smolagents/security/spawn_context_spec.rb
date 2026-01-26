require "spec_helper"

RSpec.describe Smolagents::Security::SpawnContext do
  describe ".create" do
    it "creates context with default values" do
      context = described_class.create
      expect(context.depth).to eq(0)
      expect(context.remaining_steps).to eq(100)
      expect(context.parent_tools).to eq([])
      expect(context.spawn_path).to eq([])
    end

    it "accepts custom depth" do
      context = described_class.create(depth: 2)
      expect(context.depth).to eq(2)
    end

    it "accepts custom remaining_steps" do
      context = described_class.create(remaining_steps: 50)
      expect(context.remaining_steps).to eq(50)
    end

    it "accepts custom parent_tools" do
      context = described_class.create(parent_tools: %i[search web])
      expect(context.parent_tools).to eq(%i[search web])
    end

    it "accepts custom spawn_path" do
      context = described_class.create(spawn_path: %w[root child])
      expect(context.spawn_path).to eq(%w[root child])
    end

    it "normalizes tool names to symbols" do
      context = described_class.create(parent_tools: %w[search web])
      expect(context.parent_tools).to eq(%i[search web])
    end

    it "freezes parent_tools array" do
      context = described_class.create(parent_tools: [:search])
      expect(context.parent_tools).to be_frozen
    end

    it "freezes spawn_path array" do
      context = described_class.create(spawn_path: ["root"])
      expect(context.spawn_path).to be_frozen
    end

    it "accepts array-like parent_tools" do
      context = described_class.create(parent_tools: Set.new([:search]))
      expect(context.parent_tools).to include(:search)
    end

    it "handles nil parent_tools" do
      context = described_class.create(parent_tools: nil)
      expect(context.parent_tools).to be_a(Array)
      expect(context.parent_tools).to be_frozen
    end
  end

  describe ".root" do
    it "creates a root context" do
      context = described_class.root(max_steps: 50, tools: %i[search web])
      expect(context.depth).to eq(0)
      expect(context.remaining_steps).to eq(50)
      expect(context.parent_tools).to eq(%i[search web])
    end

    it "includes agent name in spawn_path" do
      context = described_class.root(max_steps: 50, tools: [], agent_name: "root")
      expect(context.spawn_path).to eq(["root"])
    end

    it "defaults to 'root' agent name" do
      context = described_class.root(max_steps: 50, tools: [])
      expect(context.spawn_path.last).to eq("root")
    end

    it "is root context" do
      context = described_class.root(max_steps: 50, tools: [])
      expect(context.root?).to be true
    end
  end

  describe "#descend" do
    let(:parent) { described_class.create(depth: 1, remaining_steps: 100, parent_tools: %i[search web]) }

    it "increases depth by 1" do
      child = parent.descend(steps_allocated: 50)
      expect(child.depth).to eq(2)
    end

    it "sets remaining_steps to allocated steps" do
      child = parent.descend(steps_allocated: 25)
      expect(child.remaining_steps).to eq(25)
    end

    it "inherits parent tools by default" do
      child = parent.descend(steps_allocated: 50)
      expect(child.parent_tools).to eq(%i[search web])
    end

    it "uses child_tools when provided" do
      child = parent.descend(steps_allocated: 50, child_tools: [:web])
      expect(child.parent_tools).to eq(%i[web])
    end

    it "normalizes child_tools to symbols" do
      child = parent.descend(steps_allocated: 50, child_tools: %w[search web])
      expect(child.parent_tools).to eq(%i[search web])
    end

    it "freezes child tools array" do
      child = parent.descend(steps_allocated: 50, child_tools: [:web])
      expect(child.parent_tools).to be_frozen
    end

    it "appends agent name to spawn_path" do
      parent_with_path = described_class.create(spawn_path: %w[root agent1])
      child = parent_with_path.descend(steps_allocated: 50, agent_name: "agent2")
      expect(child.spawn_path).to eq(%w[root agent1 agent2])
    end

    it "defaults agent_name to 'child'" do
      child = parent.descend(steps_allocated: 50)
      expect(child.spawn_path.last).to eq("child")
    end

    it "freezes spawn_path array" do
      child = parent.descend(steps_allocated: 50)
      expect(child.spawn_path).to be_frozen
    end

    it "does not mutate parent context" do
      original_depth = parent.depth
      original_steps = parent.remaining_steps
      parent.descend(steps_allocated: 25)
      expect(parent.depth).to eq(original_depth)
      expect(parent.remaining_steps).to eq(original_steps)
    end

    it "accepts zero steps_allocated" do
      child = parent.descend(steps_allocated: 0)
      expect(child.remaining_steps).to eq(0)
    end
  end

  describe "#root?" do
    it "returns true for root context" do
      context = described_class.create(depth: 0)
      expect(context.root?).to be true
    end

    it "returns false for non-root context" do
      context = described_class.create(depth: 1)
      expect(context.root?).to be false
    end

    it "returns false for deep contexts" do
      context = described_class.create(depth: 5)
      expect(context.root?).to be false
    end
  end

  describe "#parent_name" do
    it "returns second-to-last spawn path element" do
      context = described_class.create(spawn_path: %w[root child grandchild])
      expect(context.parent_name).to eq("child")
    end

    it "returns nil for root context" do
      context = described_class.create(spawn_path: ["root"])
      expect(context.parent_name).to be_nil
    end

    it "returns nil for empty spawn_path" do
      context = described_class.create(spawn_path: [])
      expect(context.parent_name).to be_nil
    end

    it "returns nil for single element path" do
      context = described_class.create(spawn_path: ["single"])
      expect(context.parent_name).to be_nil
    end
  end

  describe "#current_name" do
    it "returns last spawn path element" do
      context = described_class.create(spawn_path: %w[root child])
      expect(context.current_name).to eq("child")
    end

    it "returns nil for empty spawn_path" do
      context = described_class.create(spawn_path: [])
      expect(context.current_name).to be_nil
    end

    it "returns single element from one-element path" do
      context = described_class.create(spawn_path: ["root"])
      expect(context.current_name).to eq("root")
    end

    it "returns deeply nested element" do
      context = described_class.create(spawn_path: %w[a b c d])
      expect(context.current_name).to eq("d")
    end
  end

  describe "#path_string" do
    it "joins spawn_path with >" do
      context = described_class.create(spawn_path: %w[root child grandchild])
      expect(context.path_string).to eq("root > child > grandchild")
    end

    it "returns single element without separator" do
      context = described_class.create(spawn_path: ["root"])
      expect(context.path_string).to eq("root")
    end

    it "returns empty string for empty path" do
      context = described_class.create(spawn_path: [])
      expect(context.path_string).to eq("")
    end

    it "uses > as separator" do
      context = described_class.create(spawn_path: %w[a b c])
      expect(context.path_string).to include(" > ")
      expect(context.path_string).to eq("a > b > c")
    end
  end

  describe "Data.define behavior" do
    it "is an immutable Data object" do
      context = described_class.create(depth: 1)
      expect { context.depth = 2 }.to raise_error(NoMethodError)
    end

    it "supports pattern matching with deconstruct_keys" do
      context = described_class.create(depth: 1, remaining_steps: 50)
      matched = case context
                in { depth: 1, remaining_steps: 50 }
                  true
                else
                  false
                end
      expect(matched).to be true
    end

    it "deconstruct_keys returns all fields" do
      context = described_class.create(depth: 2, remaining_steps: 75, parent_tools: [:search], spawn_path: ["root"])
      keys = context.deconstruct_keys(nil)
      expect(keys).to have_key(:depth)
      expect(keys).to have_key(:remaining_steps)
      expect(keys).to have_key(:parent_tools)
      expect(keys).to have_key(:spawn_path)
    end
  end

  describe "integration scenarios" do
    it "models a spawn hierarchy" do
      root = described_class.root(max_steps: 100, tools: %i[search web], agent_name: "orchestrator")
      child1 = root.descend(steps_allocated: 40, child_tools: [:search], agent_name: "researcher")
      child2 = root.descend(steps_allocated: 30, child_tools: [:web], agent_name: "fetcher")

      expect(root.root?).to be true
      expect(child1.root?).to be false
      expect(child2.root?).to be false
      expect(child1.parent_name).to eq("orchestrator")
      expect(child2.parent_name).to eq("orchestrator")
      expect(child1.path_string).to eq("orchestrator > researcher")
      expect(child2.path_string).to eq("orchestrator > fetcher")
    end

    it "allows deep nesting" do
      ctx = described_class.root(max_steps: 100, tools: [])
      3.times { |i| ctx = ctx.descend(steps_allocated: 50, agent_name: "agent#{i}") }
      expect(ctx.depth).to eq(3)
      expect(ctx.path_string).to include("agent2")
    end

    it "reduces steps as nesting increases" do
      root = described_class.root(max_steps: 100, tools: [])
      child = root.descend(steps_allocated: 40)
      grandchild = child.descend(steps_allocated: 20)

      expect(root.remaining_steps).to eq(100)
      expect(child.remaining_steps).to eq(40)
      expect(grandchild.remaining_steps).to eq(20)
    end
  end
end
