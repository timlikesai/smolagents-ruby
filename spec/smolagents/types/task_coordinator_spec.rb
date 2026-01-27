require "spec_helper"

RSpec.describe Smolagents::Types::TaskCoordinator do
  describe ".create" do
    it "creates empty coordinator" do
      coordinator = described_class.create

      expect(coordinator.tasks).to eq([])
      expect(coordinator.task_index).to eq({})
      expect(coordinator.last_task_id).to be_nil
    end
  end

  describe "#task" do
    let(:coordinator) { described_class.create }

    it "declares a new task" do
      new_coord, task = coordinator.task("First task")

      expect(task.description).to eq("First task")
      expect(new_coord.tasks.size).to eq(1)
      expect(new_coord.get(task.id)).to eq(task)
    end

    it "supports :previous dependency" do
      coord, t1 = coordinator.task("First")
      _, t2 = coord.task("Second", after: :previous)

      expect(t2.blocked_by).to eq([t1.id])
    end

    it "supports Task object dependency" do
      coord, t1 = coordinator.task("First")
      _, t2 = coord.task("Second", after: t1)

      expect(t2.blocked_by).to eq([t1.id])
    end

    it "supports string ID dependency" do
      coord, t1 = coordinator.task("First")
      _, t2 = coord.task("Second", after: t1.id)

      expect(t2.blocked_by).to eq([t1.id])
    end

    it "supports array of dependencies" do
      coord, t1 = coordinator.task("First")
      coord, t2 = coord.task("Second")
      _, t3 = coord.task("Third", after: [t1, t2])

      expect(t3.blocked_by).to contain_exactly(t1.id, t2.id)
    end

    it "accepts priority option" do
      _coord, task = coordinator.task("Urgent", priority: :critical)

      expect(task.priority).to eq(:critical)
    end

    it "accepts active_form option" do
      _coord, task = coordinator.task("Create file", active_form: "Building file")

      expect(task.active_form).to eq("Building file")
    end

    it "accepts block in metadata" do
      called = false
      _coord, task = coordinator.task("Execute") { called = true }

      task.metadata[:block].call
      expect(called).to be true
    end
  end

  describe "#get" do
    it "returns task by ID" do
      coord, task = described_class.create.task("Test")

      expect(coord.get(task.id)).to eq(task)
    end

    it "returns nil for unknown ID" do
      coord = described_class.create

      expect(coord.get("unknown")).to be_nil
    end
  end

  describe "#update" do
    it "updates a task by ID" do
      coord, task = described_class.create.task("Test")
      updated = coord.update(task.id, &:start)

      expect(updated.get(task.id).status).to eq(:in_progress)
    end

    it "returns self for unknown ID" do
      coord = described_class.create

      expect(coord.update("unknown") { |t| t }).to eq(coord)
    end
  end

  describe "#start_task" do
    it "marks task as in_progress" do
      coord, task = described_class.create.task("Test")
      coord = coord.start_task(task.id)

      expect(coord.get(task.id).status).to eq(:in_progress)
    end
  end

  describe "#complete_task" do
    it "marks task as completed" do
      coord, task = described_class.create.task("Test")
      coord = coord.start_task(task.id)
      coord = coord.complete_task(task.id, result: "done")

      expect(coord.get(task.id).status).to eq(:completed)
      expect(coord.get(task.id).result).to eq("done")
    end

    it "unblocks dependent tasks" do
      coord, t1 = described_class.create.task("First")
      coord, t2 = coord.task("Second", after: t1)

      coord = coord.start_task(t1.id)
      coord = coord.complete_task(t1.id)

      expect(coord.get(t2.id).blocked_by).to eq([])
      expect(coord.get(t2.id).actionable?).to be true
    end
  end

  describe "#fail_task" do
    it "marks task as failed" do
      coord, task = described_class.create.task("Test")
      coord = coord.start_task(task.id)
      coord = coord.fail_task(task.id, error: "oops")

      expect(coord.get(task.id).status).to eq(:failed)
      expect(coord.get(task.id).error).to eq("oops")
    end
  end

  describe "#status" do
    it "returns TaskStatus snapshot" do
      coord, _t1 = described_class.create.task("First")
      coord, _t2 = coord.task("Second")

      status = coord.status

      expect(status).to be_a(Smolagents::Types::TaskStatus)
      expect(status.total).to eq(2)
      expect(status.pending_count).to eq(2)
    end
  end

  describe "#actionable" do
    it "returns pending unblocked tasks" do
      coord, t1 = described_class.create.task("First")
      coord, = coord.task("Second", after: t1)

      expect(coord.actionable).to eq([t1])
    end
  end

  describe "#next_task" do
    it "returns highest priority actionable task" do
      coord, = described_class.create.task("Low", priority: :low)
      coord, t2 = coord.task("High", priority: :high)

      expect(coord.next_task).to eq(t2)
    end

    it "returns nil when no actionable tasks" do
      coord, t1 = described_class.create.task("First")
      coord, _t2 = coord.task("Second", after: t1)
      coord = coord.start_task(t1.id)

      expect(coord.next_task).to be_nil
    end
  end

  describe "#blocked" do
    it "returns blocked tasks" do
      coord, t1 = described_class.create.task("First")
      coord, t2 = coord.task("Second", after: t1)

      expect(coord.blocked).to eq([t2])
    end
  end

  describe "#children_of" do
    it "returns tasks with given parent_id" do
      coord, parent = described_class.create.task("Parent")
      coord, child = coord.task("Child", parent_id: parent.id)
      coord, _other = coord.task("Other")

      expect(coord.children_of(parent.id)).to eq([child])
    end
  end

  describe "#progress" do
    it "returns TaskProgress for task" do
      coord, task = described_class.create.task("Test")
      coord = coord.start_task(task.id)

      progress = coord.progress(task.id)

      expect(progress).to be_a(Smolagents::Types::TaskProgress)
      expect(progress.task_id).to eq(task.id)
    end

    it "returns nil for unknown task" do
      coord = described_class.create

      expect(coord.progress("unknown")).to be_nil
    end
  end

  describe "#size" do
    it "returns total task count" do
      coord, _t1 = described_class.create.task("First")
      coord, _t2 = coord.task("Second")

      expect(coord.size).to eq(2)
    end
  end

  describe "#empty?" do
    it "returns true when no tasks" do
      expect(described_class.create.empty?).to be true
    end

    it "returns false with tasks" do
      coord, _t = described_class.create.task("Test")

      expect(coord.empty?).to be false
    end
  end
end
