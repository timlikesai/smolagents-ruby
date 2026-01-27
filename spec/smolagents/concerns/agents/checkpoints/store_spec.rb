require "spec_helper"

RSpec.describe Smolagents::Concerns::Checkpoints::Store, type: :unit do
  subject(:store) { described_class.new(max_checkpoints:) }

  let(:max_checkpoints) { 10 }

  def make_checkpoint(step_number:, sequence: step_number, id: nil)
    Smolagents::Types::Checkpoint.new(
      id: id || "cp_#{SecureRandom.hex(8)}",
      step_number:,
      sequence:,
      memory_state: nil,
      working_memory_state: Smolagents::Types::WorkingMemoryState.empty,
      goal_state: [],
      execution_context: nil,
      model_history: [],
      tool_usage_stats: {},
      timestamp: Time.now,
      metadata: { trigger: :manual }
    )
  end

  describe "#initialize" do
    it "creates an empty store" do
      expect(store.size).to eq(0)
    end

    it "accepts max_checkpoints parameter" do
      custom_store = described_class.new(max_checkpoints: 5)
      expect(custom_store.size).to eq(0)
    end
  end

  describe "#add" do
    it "stores a checkpoint" do
      checkpoint = make_checkpoint(step_number: 1)

      result = store.add(checkpoint)

      expect(result).to eq(checkpoint)
      expect(store.size).to eq(1)
    end

    it "returns the added checkpoint" do
      checkpoint = make_checkpoint(step_number: 1)
      result = store.add(checkpoint)

      expect(result).to eq(checkpoint)
    end

    it "allows adding multiple checkpoints" do
      store.add(make_checkpoint(step_number: 1))
      store.add(make_checkpoint(step_number: 2))
      store.add(make_checkpoint(step_number: 3))

      expect(store.size).to eq(3)
    end

    context "with pruning" do
      let(:max_checkpoints) { 3 }

      it "prunes oldest checkpoints when max exceeded" do
        store.add(make_checkpoint(step_number: 1))
        store.add(make_checkpoint(step_number: 2))
        store.add(make_checkpoint(step_number: 3))
        store.add(make_checkpoint(step_number: 4))

        expect(store.size).to eq(3)
        step_numbers = store.all.map(&:step_number)
        expect(step_numbers).to eq([2, 3, 4])
      end

      it "calls pruning callback for each pruned checkpoint" do
        pruned = []
        store.add(make_checkpoint(step_number: 1))
        store.add(make_checkpoint(step_number: 2))
        store.add(make_checkpoint(step_number: 3))
        store.add(make_checkpoint(step_number: 4)) { |cp| pruned << cp }

        expect(pruned.size).to eq(1)
        expect(pruned.first.step_number).to eq(1)
      end

      it "prunes multiple checkpoints if needed" do
        store.add(make_checkpoint(step_number: 1))
        store.add(make_checkpoint(step_number: 2))
        store.add(make_checkpoint(step_number: 3))

        # Add 3 more (exceeds by 3)
        pruned = []
        store.add(make_checkpoint(step_number: 4)) { |cp| pruned << cp }
        store.add(make_checkpoint(step_number: 5)) { |cp| pruned << cp }
        store.add(make_checkpoint(step_number: 6)) { |cp| pruned << cp }

        expect(store.size).to eq(3)
        expect(pruned.size).to eq(3)
        expect(pruned.map(&:step_number)).to eq([1, 2, 3])
      end

      it "prunes by step number order (oldest first)" do
        # Add out of order
        store.add(make_checkpoint(step_number: 5))
        store.add(make_checkpoint(step_number: 2))
        store.add(make_checkpoint(step_number: 8))
        pruned = []
        store.add(make_checkpoint(step_number: 10)) { |cp| pruned << cp }

        expect(pruned.first.step_number).to eq(2)
        expect(store.all.map(&:step_number)).to eq([5, 8, 10])
      end
    end
  end

  describe "#find" do
    it "finds checkpoint by ID" do
      checkpoint = make_checkpoint(step_number: 1, id: "cp_findme12345")
      store.add(checkpoint)

      found = store.find("cp_findme12345")
      expect(found).to eq(checkpoint)
    end

    it "returns nil for unknown ID" do
      store.add(make_checkpoint(step_number: 1))

      found = store.find("cp_nonexistent")
      expect(found).to be_nil
    end

    it "finds correct checkpoint among multiple" do
      cp1 = make_checkpoint(step_number: 1, id: "cp_first1234567")
      cp2 = make_checkpoint(step_number: 2, id: "cp_second123456")
      cp3 = make_checkpoint(step_number: 3, id: "cp_third1234567")

      store.add(cp1)
      store.add(cp2)
      store.add(cp3)

      expect(store.find("cp_second123456")).to eq(cp2)
    end
  end

  describe "#all" do
    it "returns empty array for empty store" do
      expect(store.all).to eq([])
    end

    it "returns checkpoints sorted by step number" do
      store.add(make_checkpoint(step_number: 5))
      store.add(make_checkpoint(step_number: 2))
      store.add(make_checkpoint(step_number: 8))
      store.add(make_checkpoint(step_number: 1))

      step_numbers = store.all.map(&:step_number)
      expect(step_numbers).to eq([1, 2, 5, 8])
    end

    it "returns all stored checkpoints" do
      5.times { |i| store.add(make_checkpoint(step_number: i + 1)) }

      expect(store.all.size).to eq(5)
    end

    it "returns a copy (not the internal array)" do
      store.add(make_checkpoint(step_number: 1))

      result = store.all
      original_size = store.size

      result.clear

      expect(store.size).to eq(original_size)
    end
  end

  describe "#clear" do
    it "removes all checkpoints" do
      3.times { |i| store.add(make_checkpoint(step_number: i + 1)) }
      expect(store.size).to eq(3)

      store.clear

      expect(store.size).to eq(0)
      expect(store.all).to be_empty
    end

    it "calls delete callback for each checkpoint" do
      store.add(make_checkpoint(step_number: 1))
      store.add(make_checkpoint(step_number: 2))
      store.add(make_checkpoint(step_number: 3))

      deleted = []
      store.clear { |cp| deleted << cp }

      expect(deleted.size).to eq(3)
      expect(deleted.map(&:step_number)).to contain_exactly(1, 2, 3)
    end

    it "handles clearing empty store" do
      expect { store.clear }.not_to raise_error
      expect(store.size).to eq(0)
    end

    it "works without callback block" do
      store.add(make_checkpoint(step_number: 1))

      expect { store.clear }.not_to raise_error
      expect(store.size).to eq(0)
    end
  end

  describe "#load" do
    it "loads checkpoints from array" do
      checkpoints = [
        make_checkpoint(step_number: 1),
        make_checkpoint(step_number: 2),
        make_checkpoint(step_number: 3)
      ]

      store.load(checkpoints)

      expect(store.size).to eq(3)
    end

    it "adds to existing checkpoints" do
      store.add(make_checkpoint(step_number: 1))

      store.load([
                   make_checkpoint(step_number: 2),
                   make_checkpoint(step_number: 3)
                 ])

      expect(store.size).to eq(3)
    end

    it "handles empty array" do
      store.load([])
      expect(store.size).to eq(0)
    end

    it "maintains sorted order in #all after load" do
      store.load([
                   make_checkpoint(step_number: 5),
                   make_checkpoint(step_number: 2),
                   make_checkpoint(step_number: 8)
                 ])

      expect(store.all.map(&:step_number)).to eq([2, 5, 8])
    end
  end

  describe "#size" do
    it "returns 0 for empty store" do
      expect(store.size).to eq(0)
    end

    it "returns correct count after adds" do
      store.add(make_checkpoint(step_number: 1))
      expect(store.size).to eq(1)

      store.add(make_checkpoint(step_number: 2))
      expect(store.size).to eq(2)
    end

    it "reflects pruning" do
      small_store = described_class.new(max_checkpoints: 2)
      small_store.add(make_checkpoint(step_number: 1))
      small_store.add(make_checkpoint(step_number: 2))
      small_store.add(make_checkpoint(step_number: 3))

      expect(small_store.size).to eq(2)
    end

    it "reflects clearing" do
      store.add(make_checkpoint(step_number: 1))
      store.clear

      expect(store.size).to eq(0)
    end
  end

  describe "thread safety" do
    let(:max_checkpoints) { 100 }

    it "handles concurrent adds safely" do
      threads = Array.new(20) do |i|
        Thread.new do
          store.add(make_checkpoint(step_number: i + 1))
        end
      end
      threads.each(&:join)

      expect(store.size).to eq(20)
    end

    it "handles concurrent reads during writes" do
      10.times { |i| store.add(make_checkpoint(step_number: i + 1)) }

      results = []
      threads = Array.new(10) do |i|
        Thread.new do
          if i.even?
            store.add(make_checkpoint(step_number: 100 + i))
          else
            results << store.all.size
          end
        end
      end
      threads.each(&:join)

      expect(results).to all(be >= 10)
    end

    it "handles concurrent find operations" do
      cp = make_checkpoint(step_number: 1, id: "cp_concurrent123")
      store.add(cp)

      threads = Array.new(10) do
        Thread.new { store.find("cp_concurrent123") }
      end
      results = threads.map(&:value)

      expect(results).to all(eq(cp))
    end

    it "handles concurrent clear and add" do
      10.times { |i| store.add(make_checkpoint(step_number: i + 1)) }

      threads = [
        Thread.new { store.clear },
        Thread.new { store.add(make_checkpoint(step_number: 100)) }
      ]
      threads.each(&:join)

      # Either all cleared or one added after clear
      expect(store.size).to be <= 1
    end
  end

  describe "edge cases" do
    it "handles max_checkpoints of 1" do
      tiny_store = described_class.new(max_checkpoints: 1)

      tiny_store.add(make_checkpoint(step_number: 1))
      tiny_store.add(make_checkpoint(step_number: 2))

      expect(tiny_store.size).to eq(1)
      expect(tiny_store.all.first.step_number).to eq(2)
    end

    it "handles checkpoints with same step number" do
      store.add(make_checkpoint(step_number: 1, id: "cp_first1234567"))
      store.add(make_checkpoint(step_number: 1, id: "cp_second123456"))

      expect(store.size).to eq(2)
    end

    it "preserves checkpoint data through storage" do
      checkpoint = Smolagents::Types::Checkpoint.new(
        id: "cp_preserve1234",
        step_number: 5,
        sequence: 10,
        memory_state: { some: "data" },
        working_memory_state: Smolagents::Types::WorkingMemoryState.empty.with_objective("Test"),
        goal_state: [],
        execution_context: nil,
        model_history: [],
        tool_usage_stats: { "search" => 3 },
        timestamp: Time.now,
        metadata: { trigger: :recovery, custom: "value" }
      )

      store.add(checkpoint)
      found = store.find("cp_preserve1234")

      expect(found.step_number).to eq(5)
      expect(found.sequence).to eq(10)
      expect(found.memory_state).to eq({ some: "data" })
      expect(found.working_memory_state.objective).to eq("Test")
      expect(found.tool_usage_stats).to eq({ "search" => 3 })
      expect(found.metadata).to eq({ trigger: :recovery, custom: "value" })
    end
  end
end
