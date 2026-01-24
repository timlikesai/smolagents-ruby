require "spec_helper"

RSpec.describe Smolagents::Concerns::WorkingMemory do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::WorkingMemory

      def initialize
        initialize_working_memory
      end
    end
  end

  let(:instance) { test_class.new }

  describe "#initialize_working_memory" do
    it "creates empty working memory state" do
      expect(instance.working_memory).not_to be_nil
      expect(instance.working_memory.empty?).to be true
    end
  end

  describe "#update_objective" do
    it "sets the objective" do
      instance.update_objective("Find Ruby documentation")

      expect(instance.working_memory.objective).to eq("Find Ruby documentation")
    end

    it "truncates long objectives" do
      long_objective = "x" * 150
      instance.update_objective(long_objective)

      expect(instance.working_memory.objective.length).to eq(100)
      expect(instance.working_memory.objective).to end_with("...")
    end

    it "replaces previous objective" do
      instance.update_objective("First objective")
      instance.update_objective("Second objective")

      expect(instance.working_memory.objective).to eq("Second objective")
    end
  end

  describe "#record_finding" do
    it "records a finding" do
      instance.record_finding("Found 3 relevant sources")

      expect(instance.working_memory.findings).to eq(["Found 3 relevant sources"])
    end

    it "maintains most recent findings first" do
      instance.record_finding("First")
      instance.record_finding("Second")
      instance.record_finding("Third")

      expect(instance.working_memory.findings).to eq(%w[Third Second First])
    end

    it "limits to MAX_FINDINGS" do
      4.times { |i| instance.record_finding("Finding #{i}") }

      expect(instance.working_memory.findings.size).to eq(3)
      expect(instance.working_memory.findings.first).to eq("Finding 3")
    end

    it "truncates long findings" do
      long_finding = "x" * 100
      instance.record_finding(long_finding)

      expect(instance.working_memory.findings.first.length).to eq(80)
    end

    it "ignores nil findings" do
      instance.record_finding(nil)

      expect(instance.working_memory.findings).to be_empty
    end

    it "ignores empty findings" do
      instance.record_finding("")

      expect(instance.working_memory.findings).to be_empty
    end
  end

  describe "#record_blocker" do
    it "records a blocker" do
      instance.record_blocker("API rate limited")

      expect(instance.working_memory.blockers).to eq(["API rate limited"])
    end

    it "limits to MAX_BLOCKERS" do
      3.times { |i| instance.record_blocker("Blocker #{i}") }

      expect(instance.working_memory.blockers.size).to eq(2)
      expect(instance.working_memory.blockers.first).to eq("Blocker 2")
    end

    it "ignores nil blockers" do
      instance.record_blocker(nil)

      expect(instance.working_memory.blockers).to be_empty
    end
  end

  describe "#clear_blocker" do
    before do
      instance.record_blocker("API rate limited")
      instance.record_blocker("Connection timeout")
    end

    it "removes matching blocker" do
      instance.clear_blocker("rate limited")

      expect(instance.working_memory.blockers.size).to eq(1)
      expect(instance.working_memory.blockers.first).to include("timeout")
    end

    it "handles no match gracefully" do
      instance.clear_blocker("unknown")

      expect(instance.working_memory.blockers.size).to eq(2)
    end
  end

  describe "#clear_all_blockers" do
    it "removes all blockers" do
      instance.record_blocker("Blocker 1")
      instance.record_blocker("Blocker 2")
      instance.clear_all_blockers

      expect(instance.working_memory.blockers).to be_empty
    end
  end

  describe "#build_working_memory_context" do
    context "with empty memory" do
      it "returns nil" do
        expect(instance.build_working_memory_context).to be_nil
      end
    end

    context "with objective only" do
      it "includes objective" do
        instance.update_objective("Find docs")

        context = instance.build_working_memory_context
        expect(context).to eq("Objective: Find docs")
      end
    end

    context "with all components" do
      before do
        instance.update_objective("Find Ruby docs")
        instance.record_finding("Found official site")
        instance.record_finding("Found tutorial")
        instance.record_blocker("Some pages are 404")
      end

      it "includes all components" do
        context = instance.build_working_memory_context

        expect(context).to include("Objective: Find Ruby docs")
        expect(context).to include("Findings: Found tutorial; Found official site")
        expect(context).to include("Blockers: Some pages are 404")
      end

      it "formats as multiline" do
        context = instance.build_working_memory_context

        lines = context.split("\n")
        expect(lines.size).to eq(3)
      end
    end
  end

  describe "WorkingMemoryState" do
    let(:state_class) { Smolagents::Concerns::WorkingMemory::WorkingMemoryState }

    describe "#empty?" do
      it "returns true for empty state" do
        state = state_class.empty
        expect(state.empty?).to be true
      end

      it "returns false with objective" do
        state = state_class.new(objective: "test", findings: [], blockers: [])
        expect(state.empty?).to be false
      end

      it "returns false with findings" do
        state = state_class.new(objective: nil, findings: ["test"], blockers: [])
        expect(state.empty?).to be false
      end

      it "returns false with blockers" do
        state = state_class.new(objective: nil, findings: [], blockers: ["test"])
        expect(state.empty?).to be false
      end
    end

    describe "immutability" do
      it "returns new state on modification" do
        state1 = state_class.empty
        state2 = state1.with_objective("test")

        expect(state1.objective).to be_nil
        expect(state2.objective).to eq("test")
        expect(state1).not_to eq(state2)
      end

      it "is frozen" do
        state = state_class.empty
        expect(state).to be_frozen
      end
    end
  end
end
