require "spec_helper"

RSpec.describe Smolagents::Types::Wave do
  describe ".create" do
    it "creates a pending wave" do
      wave = described_class.create(number: 1, task_ids: %w[t1 t2])

      expect(wave.number).to eq(1)
      expect(wave.task_ids).to eq(%w[t1 t2])
      expect(wave.status).to eq(:pending)
      expect(wave.started_at).to be_nil
      expect(wave.completed_at).to be_nil
    end

    it "wraps single task_id in array" do
      wave = described_class.create(number: 1, task_ids: "single")

      expect(wave.task_ids).to eq(["single"])
    end
  end

  describe ".statuses" do
    it "returns valid wave statuses" do
      expect(described_class.statuses).to eq(%i[pending in_progress completed])
    end
  end

  describe "#pending?" do
    it "returns true when pending" do
      wave = described_class.create(number: 1, task_ids: [])

      expect(wave.pending?).to be true
    end
  end

  describe "#in_progress?" do
    it "returns true when in progress" do
      wave = described_class.create(number: 1, task_ids: []).start

      expect(wave.in_progress?).to be true
    end
  end

  describe "#completed?" do
    it "returns true when completed" do
      wave = described_class.create(number: 1, task_ids: []).start.complete

      expect(wave.completed?).to be true
    end
  end

  describe "#size" do
    it "returns number of tasks in wave" do
      wave = described_class.create(number: 1, task_ids: %w[a b c])

      expect(wave.size).to eq(3)
    end
  end

  describe "#empty?" do
    it "returns true when no tasks" do
      wave = described_class.create(number: 1, task_ids: [])

      expect(wave.empty?).to be true
    end

    it "returns false when tasks present" do
      wave = described_class.create(number: 1, task_ids: ["t1"])

      expect(wave.empty?).to be false
    end
  end

  describe "#elapsed_seconds" do
    it "returns nil when not started" do
      wave = described_class.create(number: 1, task_ids: [])

      expect(wave.elapsed_seconds).to be_nil
    end

    it "returns elapsed time when started" do
      wave = described_class.create(number: 1, task_ids: []).start

      expect(wave.elapsed_seconds).to be_a(Float)
    end
  end

  describe "#start" do
    it "sets status to in_progress" do
      wave = described_class.create(number: 1, task_ids: []).start

      expect(wave.status).to eq(:in_progress)
      expect(wave.started_at).to be_a(Time)
    end
  end

  describe "#complete" do
    it "sets status to completed" do
      wave = described_class.create(number: 1, task_ids: []).start.complete

      expect(wave.status).to eq(:completed)
      expect(wave.completed_at).to be_a(Time)
    end
  end

  describe "#to_s" do
    it "includes status icon and wave number" do
      wave = described_class.create(number: 2, task_ids: %w[a b c])

      expect(wave.to_s).to eq(". Wave 2: 3 task(s)")
    end

    it "uses * for in_progress" do
      wave = described_class.create(number: 1, task_ids: ["a"]).start

      expect(wave.to_s).to start_with("*")
    end

    it "uses + for completed" do
      wave = described_class.create(number: 1, task_ids: ["a"]).start.complete

      expect(wave.to_s).to start_with("+")
    end
  end
end

RSpec.describe Smolagents::Types::WavePlan do
  let(:wave_class) { Smolagents::Types::Wave }

  describe ".create" do
    it "creates a wave plan" do
      waves = [
        wave_class.create(number: 1, task_ids: %w[a b]),
        wave_class.create(number: 2, task_ids: ["c"])
      ]

      plan = described_class.create(waves:, total_tasks: 3)

      expect(plan.waves).to eq(waves)
      expect(plan.total_tasks).to eq(3)
    end
  end

  describe ".empty" do
    it "creates empty plan" do
      plan = described_class.empty

      expect(plan.waves).to eq([])
      expect(plan.total_tasks).to eq(0)
    end
  end

  describe "#wave_count" do
    it "returns number of waves" do
      waves = Array.new(3) { |i| wave_class.create(number: i + 1, task_ids: []) }
      plan = described_class.create(waves:, total_tasks: 0)

      expect(plan.wave_count).to eq(3)
    end
  end

  describe "#empty?" do
    it "returns true when no waves" do
      plan = described_class.empty

      expect(plan.empty?).to be true
    end

    it "returns false when waves present" do
      wave = wave_class.create(number: 1, task_ids: [])
      plan = described_class.create(waves: [wave], total_tasks: 0)

      expect(plan.empty?).to be false
    end
  end

  describe "#next_wave" do
    it "returns first pending wave" do
      waves = [
        wave_class.create(number: 1, task_ids: []).start.complete,
        wave_class.create(number: 2, task_ids: [])
      ]
      plan = described_class.create(waves:, total_tasks: 0)

      expect(plan.next_wave.number).to eq(2)
    end

    it "returns nil when no pending waves" do
      waves = [wave_class.create(number: 1, task_ids: []).start.complete]
      plan = described_class.create(waves:, total_tasks: 0)

      expect(plan.next_wave).to be_nil
    end
  end

  describe "#current_wave" do
    it "returns in_progress wave" do
      waves = [
        wave_class.create(number: 1, task_ids: []).start.complete,
        wave_class.create(number: 2, task_ids: []).start
      ]
      plan = described_class.create(waves:, total_tasks: 0)

      expect(plan.current_wave.number).to eq(2)
    end
  end

  describe "#completed_wave_count" do
    it "returns count of completed waves" do
      waves = [
        wave_class.create(number: 1, task_ids: []).start.complete,
        wave_class.create(number: 2, task_ids: []).start.complete,
        wave_class.create(number: 3, task_ids: [])
      ]
      plan = described_class.create(waves:, total_tasks: 0)

      expect(plan.completed_wave_count).to eq(2)
    end
  end

  describe "#progress_percent" do
    it "returns 0 when no waves" do
      plan = described_class.empty

      expect(plan.progress_percent).to eq(0.0)
    end

    it "calculates percentage of completed waves" do
      waves = [
        wave_class.create(number: 1, task_ids: []).start.complete,
        wave_class.create(number: 2, task_ids: [])
      ]
      plan = described_class.create(waves:, total_tasks: 0)

      expect(plan.progress_percent).to eq(50.0)
    end
  end

  describe "#all_done?" do
    it "returns true when all waves completed" do
      waves = [wave_class.create(number: 1, task_ids: []).start.complete]
      plan = described_class.create(waves:, total_tasks: 0)

      expect(plan.all_done?).to be true
    end

    it "returns false when waves pending" do
      waves = [wave_class.create(number: 1, task_ids: [])]
      plan = described_class.create(waves:, total_tasks: 0)

      expect(plan.all_done?).to be false
    end

    it "returns false when empty" do
      plan = described_class.empty

      expect(plan.all_done?).to be false
    end
  end

  describe "#to_s" do
    it "formats summary string" do
      waves = [
        wave_class.create(number: 1, task_ids: %w[a b]).start.complete,
        wave_class.create(number: 2, task_ids: ["c"])
      ]
      plan = described_class.create(waves:, total_tasks: 3)

      expect(plan.to_s).to eq("WavePlan: 1/2 waves, 3 tasks")
    end
  end
end
