require "spec_helper"

RSpec.describe Smolagents::Concerns::Orchestration::WaveScheduler do
  let(:task_class) { Smolagents::Types::Task }
  let(:coordinator_class) { Smolagents::Types::TaskCoordinator }

  describe ".compute_waves" do
    it "returns empty array for empty tasks" do
      waves = described_class.compute_waves([])

      expect(waves).to eq([])
    end

    it "groups independent tasks into first wave" do
      tasks = [
        task_class.create(description: "Task A"),
        task_class.create(description: "Task B"),
        task_class.create(description: "Task C")
      ]

      waves = described_class.compute_waves(tasks)

      expect(waves.size).to eq(1)
      expect(waves.first.task_ids).to match_array(tasks.map(&:id))
    end

    it "separates dependent tasks into waves" do
      t1 = task_class.create(description: "Task A")
      t2 = task_class.create(description: "Task B", after: [t1.id])

      waves = described_class.compute_waves([t1, t2])

      expect(waves.size).to eq(2)
      expect(waves[0].task_ids).to eq([t1.id])
      expect(waves[1].task_ids).to eq([t2.id])
    end

    it "handles diamond dependencies" do
      t1 = task_class.create(description: "Root")
      t2 = task_class.create(description: "Left", after: [t1.id])
      t3 = task_class.create(description: "Right", after: [t1.id])
      t4 = task_class.create(description: "Final", after: [t2.id, t3.id])

      waves = described_class.compute_waves([t1, t2, t3, t4])

      expect(waves.size).to eq(3)
      expect(waves[0].task_ids).to eq([t1.id])
      expect(waves[1].task_ids).to contain_exactly(t2.id, t3.id)
      expect(waves[2].task_ids).to eq([t4.id])
    end

    it "assigns wave numbers starting at 1" do
      t1 = task_class.create(description: "First")
      t2 = task_class.create(description: "Second", after: [t1.id])

      waves = described_class.compute_waves([t1, t2])

      expect(waves[0].number).to eq(1)
      expect(waves[1].number).to eq(2)
    end
  end

  describe ".find_ready_tasks" do
    it "finds tasks with no dependencies in remaining set" do
      t1 = task_class.create(description: "Ready")
      t2 = task_class.create(description: "Blocked", after: [t1.id])

      task_map = { t1.id => t1, t2.id => t2 }
      remaining = Set.new([t1.id, t2.id])

      ready = described_class.find_ready_tasks(remaining, task_map)

      expect(ready).to eq(Set.new([t1.id]))
    end

    it "finds task when dependency not in remaining" do
      t1 = task_class.create(description: "Done")
      t2 = task_class.create(description: "Now Ready", after: [t1.id])

      task_map = { t1.id => t1, t2.id => t2 }
      remaining = Set.new([t2.id])

      ready = described_class.find_ready_tasks(remaining, task_map)

      expect(ready).to eq(Set.new([t2.id]))
    end
  end

  describe "instance methods" do
    let(:scheduler) do
      Class.new do
        include Smolagents::Events::Emitter
        include Smolagents::Events::Consumer
        include Smolagents::Concerns::Orchestration::WaveScheduler
      end.new
    end

    describe "#build_wave_plan" do
      it "builds plan from coordinator tasks" do
        coord, t1 = coordinator_class.create.task("First")
        coord, _t2 = coord.task("Second", after: t1)

        scheduler.initialize_wave_scheduler(coord)
        plan = scheduler.build_wave_plan

        expect(plan).to be_a(Smolagents::Types::WavePlan)
        expect(plan.wave_count).to eq(2)
        expect(plan.total_tasks).to eq(2)
      end
    end

    describe "#execute_waves" do
      it "executes tasks via provided block" do
        coord, _t1 = coordinator_class.create.task("First")
        coord, _t2 = coord.task("Second")

        scheduler.initialize_wave_scheduler(coord)

        executed = []
        scheduler.execute_waves { |task| executed << task.description }

        expect(executed).to contain_exactly("First", "Second")
      end

      it "returns the wave plan" do
        coord, _t = coordinator_class.create.task("Test")
        scheduler.initialize_wave_scheduler(coord)

        plan = scheduler.execute_waves { |_| nil }

        expect(plan).to be_a(Smolagents::Types::WavePlan)
      end

      it "emits wave events" do
        coord, _t = coordinator_class.create.task("Test")
        scheduler.initialize_wave_scheduler(coord)
        allow(scheduler).to receive(:emit).and_call_original

        scheduler.execute_waves { |_| nil }

        expect(scheduler).to have_received(:emit)
          .with(:coord_wave_lifecycle, hash_including(:wave_number, phase: :started))
        expect(scheduler).to have_received(:emit)
          .with(:coord_wave_lifecycle, hash_including(:wave_number, phase: :completed))
      end
    end
  end
end
