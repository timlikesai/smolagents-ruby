require "spec_helper"

RSpec.describe Smolagents::Types::TaskStatus do
  let(:task_class) { Smolagents::Types::Task }

  describe ".from_tasks" do
    it "creates status from empty array" do
      status = described_class.from_tasks([])

      expect(status.total).to eq(0)
      expect(status.empty?).to be true
    end

    it "counts tasks by status" do
      tasks = [
        task_class.create(description: "Pending"),
        task_class.create(description: "In Progress").start,
        task_class.create(description: "Completed").start.complete(result: nil),
        task_class.create(description: "Failed").start.fail(error: "oops")
      ]

      status = described_class.from_tasks(tasks)

      expect(status.pending_count).to eq(1)
      expect(status.in_progress_count).to eq(1)
      expect(status.completed_count).to eq(1)
      expect(status.failed_count).to eq(1)
    end

    it "counts blocked tasks" do
      tasks = [
        task_class.create(description: "First"),
        task_class.create(description: "Second", after: ["first_id"])
      ]

      status = described_class.from_tasks(tasks)

      expect(status.blocked_count).to eq(1)
    end

    it "sets snapshot_at" do
      status = described_class.from_tasks([])

      expect(status.snapshot_at).to be_a(Time)
    end
  end

  describe ".empty" do
    it "creates empty status" do
      status = described_class.empty

      expect(status.total).to eq(0)
      expect(status.pending_count).to eq(0)
      expect(status.in_progress_count).to eq(0)
    end
  end

  describe "#total" do
    it "returns count of all tasks" do
      tasks = Array.new(5) { task_class.create(description: "Test") }
      status = described_class.from_tasks(tasks)

      expect(status.total).to eq(5)
    end
  end

  describe "#open" do
    it "returns pending + in_progress count" do
      tasks = [
        task_class.create(description: "Pending"),
        task_class.create(description: "In Progress").start,
        task_class.create(description: "Completed").start.complete(result: nil)
      ]

      status = described_class.from_tasks(tasks)

      expect(status.open).to eq(2)
    end
  end

  describe "#finished" do
    it "returns completed + failed + cancelled count" do
      tasks = [
        task_class.create(description: "Pending"),
        task_class.create(description: "Completed").start.complete(result: nil),
        task_class.create(description: "Failed").start.fail(error: "oops"),
        task_class.create(description: "Cancelled").cancel(reason: nil)
      ]

      status = described_class.from_tasks(tasks)

      expect(status.finished).to eq(3)
    end
  end

  describe "#progress_percent" do
    it "returns 0 when no tasks" do
      status = described_class.empty

      expect(status.progress_percent).to eq(0.0)
    end

    it "calculates percentage of finished tasks" do
      tasks = [
        task_class.create(description: "Pending"),
        task_class.create(description: "Completed").start.complete(result: nil)
      ]

      status = described_class.from_tasks(tasks)

      expect(status.progress_percent).to eq(50.0)
    end
  end

  describe "#all_done?" do
    it "returns false when tasks are pending" do
      tasks = [task_class.create(description: "Pending")]
      status = described_class.from_tasks(tasks)

      expect(status.all_done?).to be false
    end

    it "returns true when all tasks finished" do
      tasks = [task_class.create(description: "Done").start.complete(result: nil)]
      status = described_class.from_tasks(tasks)

      expect(status.all_done?).to be true
    end

    it "returns false when empty" do
      status = described_class.empty

      expect(status.all_done?).to be false
    end
  end

  describe "#any_failed?" do
    it "returns true when any task failed" do
      tasks = [task_class.create(description: "Failed").start.fail(error: "oops")]
      status = described_class.from_tasks(tasks)

      expect(status.any_failed?).to be true
    end

    it "returns false when no failures" do
      tasks = [task_class.create(description: "Pending")]
      status = described_class.from_tasks(tasks)

      expect(status.any_failed?).to be false
    end
  end

  describe "#actionable" do
    it "returns pending unblocked tasks" do
      tasks = [
        task_class.create(description: "Ready"),
        task_class.create(description: "Blocked", after: ["dep"]),
        task_class.create(description: "In Progress").start
      ]

      status = described_class.from_tasks(tasks)

      expect(status.actionable.size).to eq(1)
      expect(status.actionable.first.description).to eq("Ready")
    end
  end

  describe "#next_available" do
    it "returns highest priority actionable task" do
      tasks = [
        task_class.create(description: "Low", priority: :low),
        task_class.create(description: "Critical", priority: :critical)
      ]

      status = described_class.from_tasks(tasks)

      expect(status.next_available.description).to eq("Critical")
    end
  end

  describe "#find_task" do
    it "finds task by ID" do
      task = task_class.create(description: "Test")
      status = described_class.from_tasks([task])

      expect(status.find_task(task.id)).to eq(task)
    end

    it "returns nil for unknown ID" do
      status = described_class.empty

      expect(status.find_task("unknown")).to be_nil
    end
  end

  describe "#to_s" do
    it "formats summary string" do
      tasks = [
        task_class.create(description: "Done").start.complete(result: nil),
        task_class.create(description: "Pending"),
        task_class.create(description: "Blocked", after: ["dep"])
      ]

      status = described_class.from_tasks(tasks)

      expect(status.to_s).to include("1/3 done")
      expect(status.to_s).to include("1 blocked")
    end
  end
end
