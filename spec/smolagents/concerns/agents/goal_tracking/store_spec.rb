require "spec_helper"

RSpec.describe Smolagents::Concerns::GoalTracking::Store do
  let(:store) { described_class.new }
  let(:goal) { Smolagents::Types::Goal.create(description: "Find Ruby docs") }

  describe "#add" do
    it "adds a goal to the store" do
      store.add(goal)
      expect(store.size).to eq(1)
      expect(store.get(goal.id)).to eq(goal)
    end

    it "tracks root goals separately" do
      store.add(goal)
      expect(store.roots).to eq([goal])
    end

    it "does not track subgoals as roots" do
      store.add(goal)
      subgoal = Smolagents::Types::Goal.create(description: "Search", parent_id: goal.id)
      store.add(subgoal)

      expect(store.roots).to eq([goal])
      expect(store.size).to eq(2)
    end

    it "returns the added goal" do
      result = store.add(goal)
      expect(result).to eq(goal)
    end
  end

  describe "#update" do
    it "updates a goal using a block" do
      store.add(goal)
      updated = store.update(goal.id) { |g| g.complete(evidence: "Done") }

      expect(updated.completed?).to be true
      expect(updated.progress).to eq("Done")
      expect(store.get(goal.id)).to eq(updated)
    end

    it "returns nil for unknown ID" do
      result = store.update("unknown") { |g| g }
      expect(result).to be_nil
    end

    it "preserves goal in store after completion" do
      store.add(goal)
      store.update(goal.id) { |g| g.complete(evidence: "Done") }

      expect(store.size).to eq(1)
      expect(store.get(goal.id).completed?).to be true
    end
  end

  describe "#get" do
    it "returns goal by ID" do
      store.add(goal)
      expect(store.get(goal.id)).to eq(goal)
    end

    it "returns nil for unknown ID" do
      expect(store.get("unknown")).to be_nil
    end
  end

  describe "#current" do
    it "returns the most recent active root goal" do
      goal1 = Smolagents::Types::Goal.create(description: "First")
      goal2 = Smolagents::Types::Goal.create(description: "Second")

      store.add(goal1)
      store.add(goal2)

      expect(store.current).to eq(goal2)
    end

    it "skips completed goals" do
      goal1 = Smolagents::Types::Goal.create(description: "First")
      goal2 = Smolagents::Types::Goal.create(description: "Second")

      store.add(goal1)
      store.add(goal2)
      store.update(goal2.id) { |g| g.complete(evidence: "Done") }

      expect(store.current).to eq(goal1)
    end

    it "returns nil when no active goals" do
      store.add(goal)
      store.update(goal.id) { |g| g.complete(evidence: "Done") }

      expect(store.current).to be_nil
    end

    it "returns nil for empty store" do
      expect(store.current).to be_nil
    end

    it "ignores subgoals" do
      store.add(goal)
      subgoal = Smolagents::Types::Goal.create(description: "Sub", parent_id: goal.id)
      store.add(subgoal)
      store.update(goal.id) { |g| g.complete(evidence: "Done") }

      # Subgoal is active but not a root
      expect(store.current).to be_nil
    end
  end

  describe "#roots" do
    it "returns all root goals in creation order" do
      goal1 = Smolagents::Types::Goal.create(description: "First")
      goal2 = Smolagents::Types::Goal.create(description: "Second")

      store.add(goal1)
      store.add(goal2)

      expect(store.roots).to eq([goal1, goal2])
    end

    it "excludes subgoals" do
      store.add(goal)
      subgoal = Smolagents::Types::Goal.create(description: "Sub", parent_id: goal.id)
      store.add(subgoal)

      expect(store.roots).to eq([goal])
    end
  end

  describe "#children_of" do
    it "returns children of a goal" do
      store.add(goal)
      child1 = Smolagents::Types::Goal.create(description: "Child 1", parent_id: goal.id)
      child2 = Smolagents::Types::Goal.create(description: "Child 2", parent_id: goal.id)
      store.add(child1)
      store.add(child2)

      children = store.children_of(goal.id)
      expect(children).to contain_exactly(child1, child2)
    end

    it "returns empty array for goal without children" do
      store.add(goal)
      expect(store.children_of(goal.id)).to be_empty
    end
  end

  describe "#active" do
    it "returns only active goals" do
      goal1 = Smolagents::Types::Goal.create(description: "Active")
      goal2 = Smolagents::Types::Goal.create(description: "Completed")

      store.add(goal1)
      store.add(goal2)
      store.update(goal2.id) { |g| g.complete(evidence: "Done") }

      expect(store.active).to eq([goal1])
    end
  end

  describe "#open" do
    it "returns active and blocked goals" do
      goal1 = Smolagents::Types::Goal.create(description: "Active")
      goal2 = Smolagents::Types::Goal.create(description: "Blocked")
      goal3 = Smolagents::Types::Goal.create(description: "Completed")

      store.add(goal1)
      store.add(goal2)
      store.add(goal3)
      store.update(goal2.id) { |g| g.block(reason: "Waiting") }
      store.update(goal3.id) { |g| g.complete(evidence: "Done") }

      open_goals = store.open
      expect(open_goals.size).to eq(2)
      expect(open_goals.map(&:description)).to contain_exactly("Active", "Blocked")
    end
  end

  describe "#completed" do
    it "returns only completed goals" do
      goal1 = Smolagents::Types::Goal.create(description: "Active")
      goal2 = Smolagents::Types::Goal.create(description: "Completed")

      store.add(goal1)
      store.add(goal2)
      store.update(goal2.id) { |g| g.complete(evidence: "Done") }

      completed = store.completed
      expect(completed.size).to eq(1)
      expect(completed.first.description).to eq("Completed")
    end
  end

  describe "#all" do
    it "returns all goals regardless of status" do
      goal1 = Smolagents::Types::Goal.create(description: "Active")
      goal2 = Smolagents::Types::Goal.create(description: "Completed")

      store.add(goal1)
      store.add(goal2)
      store.update(goal2.id) { |g| g.complete(evidence: "Done") }

      expect(store.all.size).to eq(2)
    end
  end

  describe "#clear" do
    it "removes all goals" do
      store.add(goal)
      store.clear

      expect(store.size).to eq(0)
      expect(store.roots).to be_empty
    end
  end

  describe "#size" do
    it "returns number of goals" do
      expect(store.size).to eq(0)
      store.add(goal)
      expect(store.size).to eq(1)
    end
  end

  describe "#empty?" do
    it "returns true for empty store" do
      expect(store.empty?).to be true
    end

    it "returns false when goals exist" do
      store.add(goal)
      expect(store.empty?).to be false
    end
  end

  describe "thread safety" do
    it "handles concurrent adds" do
      threads = Array.new(10) do |i|
        Thread.new do
          g = Smolagents::Types::Goal.create(description: "Goal #{i}")
          store.add(g)
        end
      end
      threads.each(&:join)

      expect(store.size).to eq(10)
    end

    it "handles concurrent updates" do
      store.add(goal)

      threads = Array.new(3) do |i|
        Thread.new do
          store.update(goal.id) { |g| g.update_progress("Update #{i}") }
        end
      end
      threads.each(&:join)

      # Goal should still exist with some progress
      expect(store.get(goal.id)).not_to be_nil
    end
  end

  describe "goal history preservation" do
    it "preserves completed goals in history" do
      goal1 = Smolagents::Types::Goal.create(description: "Task 1")
      goal2 = Smolagents::Types::Goal.create(description: "Task 2")

      store.add(goal1)
      store.update(goal1.id) { |g| g.complete(evidence: "Done 1") }

      store.add(goal2)
      store.update(goal2.id) { |g| g.complete(evidence: "Done 2") }

      # Both goals are preserved
      expect(store.size).to eq(2)
      expect(store.completed.size).to eq(2)
      expect(store.roots.size).to eq(2)
    end
  end
end
