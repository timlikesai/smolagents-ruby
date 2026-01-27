require "spec_helper"

RSpec.describe Smolagents::Types::Task do
  describe ".statuses" do
    it "returns valid status symbols" do
      expect(described_class.statuses).to eq(%i[pending in_progress completed failed cancelled])
    end
  end

  describe ".priorities" do
    it "returns valid priority symbols" do
      expect(described_class.priorities).to eq(%i[low normal high critical])
    end
  end

  describe ".create" do
    it "creates a pending task with defaults" do
      task = described_class.create(description: "Test task")

      expect(task.id).to start_with("task_")
      expect(task.description).to eq("Test task")
      expect(task.status).to eq(:pending)
      expect(task.priority).to eq(:normal)
      expect(task.blocked_by).to eq([])
    end

    it "derives active_form from description" do
      task = described_class.create(description: "Create types")

      expect(task.active_form).to eq("Creating types")
    end

    it "accepts custom active_form" do
      task = described_class.create(description: "Create types", active_form: "Building types")

      expect(task.active_form).to eq("Building types")
    end

    it "accepts custom priority" do
      task = described_class.create(description: "Urgent task", priority: :critical)

      expect(task.priority).to eq(:critical)
    end

    it "accepts timeout" do
      task = described_class.create(description: "Test", timeout: 30)

      expect(task.timeout_seconds).to eq(30)
    end

    it "accepts metadata" do
      task = described_class.create(description: "Test", metadata: { key: "value" })

      expect(task.metadata).to eq({ key: "value" })
    end

    it "raises on invalid priority" do
      expect { described_class.create(description: "Test", priority: :invalid) }
        .to raise_error(ArgumentError, /Invalid priority/)
    end
  end

  describe "status predicates" do
    let(:pending_task) { described_class.create(description: "Test") }

    it "#pending? returns true for pending tasks" do
      expect(pending_task.pending?).to be true
      expect(pending_task.in_progress?).to be false
      expect(pending_task.completed?).to be false
      expect(pending_task.failed?).to be false
      expect(pending_task.cancelled?).to be false
    end

    it "#in_progress? returns true after start" do
      task = pending_task.start

      expect(task.in_progress?).to be true
      expect(task.pending?).to be false
    end

    it "#completed? returns true after complete" do
      task = pending_task.start.complete(result: "done")

      expect(task.completed?).to be true
      expect(task.finished?).to be true
    end

    it "#failed? returns true after fail" do
      task = pending_task.start.fail(error: "oops")

      expect(task.failed?).to be true
      expect(task.finished?).to be true
    end

    it "#cancelled? returns true after cancel" do
      task = pending_task.cancel(reason: "no longer needed")

      expect(task.cancelled?).to be true
      expect(task.finished?).to be true
    end
  end

  describe "#blocked?" do
    it "returns false when no dependencies" do
      task = described_class.create(description: "Test")

      expect(task.blocked?).to be false
    end

    it "returns true when dependencies present" do
      task = described_class.create(description: "Test", after: ["dep1"])

      expect(task.blocked?).to be true
      expect(task.blocked_by).to eq(["dep1"])
    end
  end

  describe "#actionable?" do
    it "returns true for pending unblocked tasks" do
      task = described_class.create(description: "Test")

      expect(task.actionable?).to be true
    end

    it "returns false for blocked tasks" do
      task = described_class.create(description: "Test", after: ["dep1"])

      expect(task.actionable?).to be false
    end

    it "returns false for in_progress tasks" do
      task = described_class.create(description: "Test").start

      expect(task.actionable?).to be false
    end
  end

  describe "#critical?" do
    it "returns true for critical priority" do
      task = described_class.create(description: "Test", priority: :critical)

      expect(task.critical?).to be true
    end

    it "returns false for other priorities" do
      task = described_class.create(description: "Test", priority: :high)

      expect(task.critical?).to be false
    end
  end

  describe "#root?" do
    it "returns true when no parent_id" do
      task = described_class.create(description: "Test")

      expect(task.root?).to be true
    end

    it "returns false with parent_id" do
      task = described_class.create(description: "Test", parent_id: "parent123")

      expect(task.root?).to be false
    end
  end

  describe "#elapsed_seconds" do
    it "returns nil when not started" do
      task = described_class.create(description: "Test")

      expect(task.elapsed_seconds).to be_nil
    end

    it "returns elapsed time when started" do
      task = described_class.create(description: "Test").start

      expect(task.elapsed_seconds).to be_a(Float)
    end
  end

  describe "state transitions" do
    let(:task) { described_class.create(description: "Test") }

    it "#start sets status and started_at" do
      started = task.start

      expect(started.status).to eq(:in_progress)
      expect(started.started_at).to be_a(Time)
    end

    it "#complete sets status, result, and completed_at" do
      completed = task.start.complete(result: "done")

      expect(completed.status).to eq(:completed)
      expect(completed.result).to eq("done")
      expect(completed.completed_at).to be_a(Time)
    end

    it "#fail sets status, error, and completed_at" do
      failed = task.start.fail(error: "oops")

      expect(failed.status).to eq(:failed)
      expect(failed.error).to eq("oops")
      expect(failed.completed_at).to be_a(Time)
    end

    it "#cancel sets status, reason, and completed_at" do
      cancelled = task.cancel(reason: "no longer needed")

      expect(cancelled.status).to eq(:cancelled)
      expect(cancelled.error).to eq("no longer needed")
      expect(cancelled.completed_at).to be_a(Time)
    end

    it "#unblock removes a dependency" do
      blocked = described_class.create(description: "Test", after: %w[dep1 dep2])
      unblocked = blocked.unblock("dep1")

      expect(unblocked.blocked_by).to eq(["dep2"])
    end
  end

  describe "#to_s" do
    it "includes status icon, priority, and description" do
      task = described_class.create(description: "Build feature", priority: :high)

      expect(task.to_s).to include("[high]")
      expect(task.to_s).to include("Build feature")
      expect(task.to_s).to start_with(".")
    end

    it "includes blocked info when blocked" do
      task = described_class.create(description: "Test", after: ["dep1"])

      expect(task.to_s).to include("[blocked by: dep1]")
    end
  end
end
