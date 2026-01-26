RSpec.describe Smolagents::Types::WorkingMemoryState do
  describe ".empty" do
    it "creates state with nil objective" do
      state = described_class.empty

      expect(state.objective).to be_nil
    end

    it "creates state with empty findings" do
      state = described_class.empty

      expect(state.findings).to eq([])
    end

    it "creates state with empty blockers" do
      state = described_class.empty

      expect(state.blockers).to eq([])
    end

    it "is frozen" do
      state = described_class.empty

      expect(state).to be_frozen
    end
  end

  describe "#with_objective" do
    it "sets the objective" do
      state = described_class.empty.with_objective("Find Ruby release notes")

      expect(state.objective).to eq("Find Ruby release notes")
    end

    it "truncates long objectives" do
      long_objective = "x" * 150
      state = described_class.empty.with_objective(long_objective)

      expect(state.objective.length).to be <= 100
      expect(state.objective).to end_with("...")
    end

    it "returns new frozen instance" do
      original = described_class.empty
      updated = original.with_objective("New goal")

      expect(updated).to be_frozen
      expect(original.objective).to be_nil
    end
  end

  describe "#add_finding" do
    it "adds a finding to the front" do
      state = described_class.empty
                             .add_finding("First finding")
                             .add_finding("Second finding")

      expect(state.findings).to eq(["Second finding", "First finding"])
    end

    it "limits findings to 3 (MAX_FINDINGS)" do
      state = described_class.empty
      5.times { |i| state = state.add_finding("Finding #{i}") }

      expect(state.findings.length).to eq(3)
      expect(state.findings.first).to eq("Finding 4")
    end

    it "truncates long findings" do
      long_finding = "y" * 100
      state = described_class.empty.add_finding(long_finding)

      expect(state.findings.first.length).to be <= 80
      expect(state.findings.first).to end_with("...")
    end

    it "returns new frozen instance" do
      original = described_class.empty
      updated = original.add_finding("Finding")

      expect(updated).to be_frozen
      expect(original.findings).to be_empty
    end
  end

  describe "#add_blocker" do
    it "adds a blocker to the front" do
      state = described_class.empty
                             .add_blocker("First blocker")
                             .add_blocker("Second blocker")

      expect(state.blockers).to eq(["Second blocker", "First blocker"])
    end

    it "limits blockers to 2 (MAX_BLOCKERS)" do
      state = described_class.empty
      5.times { |i| state = state.add_blocker("Blocker #{i}") }

      expect(state.blockers.length).to eq(2)
      expect(state.blockers.first).to eq("Blocker 4")
    end

    it "truncates long blockers" do
      long_blocker = "z" * 100
      state = described_class.empty.add_blocker(long_blocker)

      expect(state.blockers.first.length).to be <= 60
      expect(state.blockers.first).to end_with("...")
    end

    it "returns new frozen instance" do
      original = described_class.empty
      updated = original.add_blocker("Blocker")

      expect(updated).to be_frozen
      expect(original.blockers).to be_empty
    end
  end

  describe "#remove_blocker" do
    it "removes blocker by exact match" do
      state = described_class.empty
                             .add_blocker("API rate limited")
                             .add_blocker("Connection timeout")

      updated = state.remove_blocker("API rate limited")

      expect(updated.blockers).to eq(["Connection timeout"])
    end

    it "removes blocker by partial match" do
      state = described_class.empty.add_blocker("API rate limited")

      updated = state.remove_blocker("rate")

      expect(updated.blockers).to be_empty
    end

    it "removes blocker when blocker contains the search term" do
      state = described_class.empty.add_blocker("API rate limit exceeded")

      updated = state.remove_blocker("rate limit")

      expect(updated.blockers).to be_empty
    end

    it "does nothing when no match" do
      state = described_class.empty.add_blocker("Some blocker")

      updated = state.remove_blocker("unrelated")

      expect(updated.blockers).to eq(["Some blocker"])
    end

    it "returns frozen instance" do
      state = described_class.empty.add_blocker("Test")

      expect(state.remove_blocker("Test")).to be_frozen
    end
  end

  describe "#clear_blockers" do
    it "removes all blockers" do
      state = described_class.empty
                             .add_blocker("Blocker 1")
                             .add_blocker("Blocker 2")

      updated = state.clear_blockers

      expect(updated.blockers).to be_empty
    end

    it "preserves other fields" do
      state = described_class.empty
                             .with_objective("Goal")
                             .add_finding("Finding")
                             .add_blocker("Blocker")

      updated = state.clear_blockers

      expect(updated.objective).to eq("Goal")
      expect(updated.findings).to eq(["Finding"])
    end

    it "returns frozen instance" do
      state = described_class.empty.add_blocker("Test")

      expect(state.clear_blockers).to be_frozen
    end
  end

  describe "#to_context" do
    it "returns nil when empty" do
      state = described_class.empty

      expect(state.to_context).to be_nil
    end

    it "includes objective when set" do
      state = described_class.empty.with_objective("Find Ruby info")

      expect(state.to_context).to include("Objective: Find Ruby info")
    end

    it "includes findings when present" do
      state = described_class.empty
                             .add_finding("Found blog post")
                             .add_finding("Found docs")

      context = state.to_context

      expect(context).to include("Findings:")
      expect(context).to include("Found docs")
      expect(context).to include("Found blog post")
    end

    it "includes blockers when present" do
      state = described_class.empty.add_blocker("Rate limited")

      expect(state.to_context).to include("Blockers: Rate limited")
    end

    it "joins multiple parts with newlines" do
      state = described_class.empty
                             .with_objective("Goal")
                             .add_finding("Finding")
                             .add_blocker("Blocker")

      context = state.to_context

      expect(context.lines.length).to eq(3)
    end
  end

  describe "#empty?" do
    it "returns true when all fields are empty/nil" do
      state = described_class.empty

      expect(state.empty?).to be true
    end

    it "returns false when objective is set" do
      state = described_class.empty.with_objective("Goal")

      expect(state.empty?).to be false
    end

    it "returns false when findings are present" do
      state = described_class.empty.add_finding("Finding")

      expect(state.empty?).to be false
    end

    it "returns false when blockers are present" do
      state = described_class.empty.add_blocker("Blocker")

      expect(state.empty?).to be false
    end
  end

  describe "limits" do
    it "limits findings to 3" do
      state = described_class.empty
      10.times { |i| state = state.add_finding("F#{i}") }
      expect(state.findings.length).to eq(3)
    end

    it "limits blockers to 2" do
      state = described_class.empty
      10.times { |i| state = state.add_blocker("B#{i}") }
      expect(state.blockers.length).to eq(2)
    end
  end

  describe "immutability" do
    it "all operations return new frozen instances" do
      state = described_class.empty

      expect(state.with_objective("x")).to be_frozen
      expect(state.add_finding("x")).to be_frozen
      expect(state.add_blocker("x")).to be_frozen
      expect(state.clear_blockers).to be_frozen
    end

    it "original state is unchanged by operations" do
      original = described_class.empty
      _ = original.with_objective("New goal")
      _ = original.add_finding("Finding")
      _ = original.add_blocker("Blocker")

      expect(original.objective).to be_nil
      expect(original.findings).to be_empty
      expect(original.blockers).to be_empty
    end
  end
end
