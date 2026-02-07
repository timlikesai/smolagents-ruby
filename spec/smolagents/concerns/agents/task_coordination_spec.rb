require "spec_helper"

RSpec.describe Smolagents::Concerns::Agents::TaskCoordination do
  let(:coordinator_class) do
    Class.new do
      include Smolagents::Events::Emitter
      include Smolagents::Events::Consumer
      include Smolagents::Concerns::Agents::TaskCoordination

      attr_writer :task_coordinator

      def initialize = initialize_task_coordination
    end
  end

  let(:coordinator) { coordinator_class.new }

  describe "#initialize_task_coordination" do
    it "creates empty task coordinator" do
      expect(coordinator.task_coordinator).to be_a(Smolagents::Types::TaskCoordinator)
      expect(coordinator.task_coordinator.empty?).to be true
    end
  end

  describe "#declare_task" do
    it "adds task to coordinator" do
      task = coordinator.declare_task("Test task")

      expect(task.description).to eq("Test task")
      expect(coordinator.task_coordinator.size).to eq(1)
    end

    it "supports dependencies" do
      t1 = coordinator.declare_task("First")
      t2 = coordinator.declare_task("Second", after: t1)

      expect(t2.blocked_by).to eq([t1.id])
    end

    it "supports priority" do
      task = coordinator.declare_task("Urgent", priority: :critical)

      expect(task.priority).to eq(:critical)
    end

    it "emits task_created event" do
      allow(coordinator).to receive(:emit).and_call_original

      coordinator.declare_task("Test")

      expect(coordinator).to have_received(:emit).with(:coord_task_lifecycle, hash_including(:task_id, :description))
    end
  end

  describe "#start_task" do
    it "marks task as in_progress" do
      task = coordinator.declare_task("Test")
      coordinator.start_task(task.id)

      expect(coordinator.task_coordinator.get(task.id).status).to eq(:in_progress)
    end

    it "emits task_started event" do
      task = coordinator.declare_task("Test")
      allow(coordinator).to receive(:emit).and_call_original

      coordinator.start_task(task.id)

      expect(coordinator).to have_received(:emit).with(:coord_task_lifecycle, hash_including(:task_id))
    end
  end

  describe "#complete_task" do
    it "marks task as completed" do
      task = coordinator.declare_task("Test")
      coordinator.start_task(task.id)
      coordinator.complete_task(task.id, result: "done")

      expect(coordinator.task_coordinator.get(task.id).status).to eq(:completed)
      expect(coordinator.task_coordinator.get(task.id).result).to eq("done")
    end

    it "emits task_completed event" do
      task = coordinator.declare_task("Test")
      coordinator.start_task(task.id)
      allow(coordinator).to receive(:emit).and_call_original

      coordinator.complete_task(task.id)

      expect(coordinator).to have_received(:emit).with(:coord_task_lifecycle, hash_including(:task_id))
    end
  end

  describe "query methods" do
    describe "#task_status" do
      it "returns TaskStatus" do
        coordinator.declare_task("Test")

        status = coordinator.task_status

        expect(status).to be_a(Smolagents::Types::TaskStatus)
        expect(status.total).to eq(1)
      end

      it "returns empty status when no tasks" do
        status = coordinator.task_status

        expect(status.empty?).to be true
      end
    end

    describe "#find_task" do
      it "finds task by ID" do
        task = coordinator.declare_task("Test")

        found = coordinator.find_task(task.id)

        expect(found).to eq(task)
      end
    end

    describe "#actionable_tasks" do
      it "returns pending unblocked tasks" do
        t1 = coordinator.declare_task("Ready")
        _t2 = coordinator.declare_task("Blocked", after: t1)

        actionable = coordinator.actionable_tasks

        expect(actionable.size).to eq(1)
        expect(actionable.first.id).to eq(t1.id)
      end
    end

    describe "#next_available_task" do
      it "returns highest priority actionable" do
        _low = coordinator.declare_task("Low", priority: :low)
        high = coordinator.declare_task("High", priority: :high)

        expect(coordinator.next_available_task.id).to eq(high.id)
      end
    end

    describe "#blocked_tasks" do
      it "returns blocked tasks" do
        t1 = coordinator.declare_task("First")
        t2 = coordinator.declare_task("Second", after: t1)

        blocked = coordinator.blocked_tasks

        expect(blocked.size).to eq(1)
        expect(blocked.first.id).to eq(t2.id)
      end
    end

    describe "#all_tasks_done?" do
      it "returns false when tasks pending" do
        coordinator.declare_task("Pending")

        expect(coordinator.all_tasks_done?).to be false
      end

      it "returns true when all completed" do
        task = coordinator.declare_task("Test")
        coordinator.start_task(task.id)
        coordinator.complete_task(task.id)

        expect(coordinator.all_tasks_done?).to be true
      end
    end

    describe "#any_tasks_failed?" do
      it "returns true when tasks failed" do
        task = coordinator.declare_task("Test")
        coordinator.start_task(task.id)
        coordinator.task_coordinator = coordinator.task_coordinator.fail_task(task.id, error: "oops")

        expect(coordinator.any_tasks_failed?).to be true
      end
    end
  end

  describe "progress methods" do
    describe "#task_progress" do
      it "returns TaskProgress for task" do
        task = coordinator.declare_task("Test")
        coordinator.start_task(task.id)

        progress = coordinator.task_progress(task.id)

        expect(progress).to be_a(Smolagents::Types::TaskProgress)
        expect(progress.status).to eq(:in_progress)
      end
    end

    describe "#overall_progress_percent" do
      it "returns percentage of finished tasks" do
        t1 = coordinator.declare_task("Done")
        _t2 = coordinator.declare_task("Pending")

        coordinator.start_task(t1.id)
        coordinator.complete_task(t1.id)

        expect(coordinator.overall_progress_percent).to eq(50.0)
      end
    end

    describe "#overall_progress_bar" do
      it "returns formatted progress bar" do
        task = coordinator.declare_task("Test")
        coordinator.start_task(task.id)
        coordinator.complete_task(task.id)

        bar = coordinator.overall_progress_bar(width: 10)

        expect(bar).to include("[")
        expect(bar).to include("]")
        expect(bar).to include("100%")
      end
    end

    describe "#task_summary" do
      it "returns formatted summary" do
        t1 = coordinator.declare_task("Done")
        _t2 = coordinator.declare_task("Blocked", after: t1)

        coordinator.start_task(t1.id)
        coordinator.complete_task(t1.id)

        summary = coordinator.task_summary

        expect(summary).to include("1/2 done")
        expect(summary).to include("0 blocked")
        expect(summary).to include("0 running")
      end
    end
  end

  describe "#run_coordinated" do
    it "executes tasks with coordination" do
      executed = []

      coordinator.run_coordinated("Main task") do |_coord|
        executed << "block called"
      end

      expect(executed).to eq(["block called"])
    end
  end

  private

  def coordinator
    @coordinator ||= coordinator_class.new
  end
end
