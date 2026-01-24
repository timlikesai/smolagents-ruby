require "spec_helper"

RSpec.describe Smolagents::Types::Goal do
  describe ".create" do
    it "creates an active root goal with generated ID" do
      goal = described_class.create(description: "Find Ruby docs")

      expect(goal.id).to match(/^goal_[a-f0-9]{8}$/)
      expect(goal.description).to eq("Find Ruby docs")
      expect(goal.status).to eq(:active)
      expect(goal.progress).to be_nil
      expect(goal.parent_id).to be_nil
      expect(goal.created_at).to be_within(1).of(Time.now)
    end

    it "creates a subgoal with parent_id" do
      parent = described_class.create(description: "Main goal")
      child = described_class.create(description: "Subgoal", parent_id: parent.id)

      expect(child.parent_id).to eq(parent.id)
      expect(child.root?).to be false
    end

    it "accepts initial progress" do
      goal = described_class.create(description: "Goal", progress: "Starting")

      expect(goal.progress).to eq("Starting")
    end
  end

  describe "status predicates" do
    let(:active) { described_class.create(description: "Active") }
    let(:blocked) { active.block(reason: "Waiting") }
    let(:completed) { active.complete(evidence: "Done") }
    let(:abandoned) { active.abandon(reason: "Not needed") }

    it "active? returns true only for active goals" do
      expect(active.active?).to be true
      expect(blocked.active?).to be false
      expect(completed.active?).to be false
      expect(abandoned.active?).to be false
    end

    it "blocked? returns true only for blocked goals" do
      expect(active.blocked?).to be false
      expect(blocked.blocked?).to be true
      expect(completed.blocked?).to be false
      expect(abandoned.blocked?).to be false
    end

    it "completed? returns true only for completed goals" do
      expect(active.completed?).to be false
      expect(blocked.completed?).to be false
      expect(completed.completed?).to be true
      expect(abandoned.completed?).to be false
    end

    it "abandoned? returns true only for abandoned goals" do
      expect(active.abandoned?).to be false
      expect(blocked.abandoned?).to be false
      expect(completed.abandoned?).to be false
      expect(abandoned.abandoned?).to be true
    end

    it "open? returns true for active or blocked" do
      expect(active.open?).to be true
      expect(blocked.open?).to be true
      expect(completed.open?).to be false
      expect(abandoned.open?).to be false
    end

    it "closed? returns true for completed or abandoned" do
      expect(active.closed?).to be false
      expect(blocked.closed?).to be false
      expect(completed.closed?).to be true
      expect(abandoned.closed?).to be true
    end
  end

  describe "hierarchy predicates" do
    it "root? returns true for goals without parent" do
      root = described_class.create(description: "Root")
      expect(root.root?).to be true
    end

    it "root? returns false for goals with parent" do
      parent = described_class.create(description: "Parent")
      child = described_class.create(description: "Child", parent_id: parent.id)
      expect(child.root?).to be false
    end
  end

  describe "#complete" do
    it "returns new goal with completed status and evidence" do
      goal = described_class.create(description: "Task")
      completed = goal.complete(evidence: "Found 3 results")

      expect(completed.status).to eq(:completed)
      expect(completed.progress).to eq("Found 3 results")
      expect(completed.id).to eq(goal.id) # Same ID
      expect(goal.status).to eq(:active) # Original unchanged
    end
  end

  describe "#block" do
    it "returns new goal with blocked status and reason" do
      goal = described_class.create(description: "Task")
      blocked = goal.block(reason: "Waiting for API")

      expect(blocked.status).to eq(:blocked)
      expect(blocked.progress).to eq("Waiting for API")
    end
  end

  describe "#unblock" do
    it "returns blocked goal to active status" do
      goal = described_class.create(description: "Task")
      blocked = goal.block(reason: "Waiting")
      unblocked = blocked.unblock

      expect(unblocked.status).to eq(:active)
      expect(unblocked.progress).to eq("Waiting") # Progress preserved
    end
  end

  describe "#abandon" do
    it "returns new goal with abandoned status and reason" do
      goal = described_class.create(description: "Task")
      abandoned = goal.abandon(reason: "No longer needed")

      expect(abandoned.status).to eq(:abandoned)
      expect(abandoned.progress).to eq("No longer needed")
    end
  end

  describe "#update_progress" do
    it "updates progress without changing status" do
      goal = described_class.create(description: "Task")
      updated = goal.update_progress("50% complete")

      expect(updated.progress).to eq("50% complete")
      expect(updated.status).to eq(:active)
    end
  end

  describe "#to_h" do
    it "returns goal as hash with ISO8601 timestamp" do
      goal = described_class.create(description: "Task", progress: "Starting")
      hash = goal.to_h

      expect(hash[:id]).to eq(goal.id)
      expect(hash[:description]).to eq("Task")
      expect(hash[:status]).to eq(:active)
      expect(hash[:progress]).to eq("Starting")
      expect(hash[:parent_id]).to be_nil
      expect(hash[:created_at]).to match(/^\d{4}-\d{2}-\d{2}T/)
    end
  end

  describe "#to_s" do
    it "returns compact string representation" do
      goal = described_class.create(description: "Find Ruby docs")
      expect(goal.to_s).to eq("[active] Find Ruby docs")
    end

    it "reflects current status" do
      goal = described_class.create(description: "Task").complete(evidence: "Done")
      expect(goal.to_s).to eq("[completed] Task")
    end
  end

  describe "immutability" do
    it "state transitions return new instances" do
      original = described_class.create(description: "Task")
      completed = original.complete(evidence: "Done")

      expect(original.object_id).not_to eq(completed.object_id)
      expect(original.status).to eq(:active)
      expect(completed.status).to eq(:completed)
    end
  end

  describe "pattern matching" do
    it "matches on status" do
      goal = described_class.create(description: "Task")

      result = case goal
               in Smolagents::Types::Goal[status: :active, description:]
                 "Active: #{description}"
               else
                 "Other"
               end

      expect(result).to eq("Active: Task")
    end

    it "matches completed goals" do
      goal = described_class.create(description: "Task").complete(evidence: "Done")

      result = case goal
               in Smolagents::Types::Goal[status: :completed, progress:]
                 "Completed: #{progress}"
               else
                 "Other"
               end

      expect(result).to eq("Completed: Done")
    end
  end

  describe "GOAL_STATUSES" do
    it "defines valid statuses" do
      expect(Smolagents::Types::GOAL_STATUSES).to eq(%i[active blocked completed abandoned])
    end
  end
end
