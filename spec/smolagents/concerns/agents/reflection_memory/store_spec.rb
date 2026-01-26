require "smolagents/concerns/agents/reflection_memory/store"
require "smolagents/types/reflection"

RSpec.describe Smolagents::Concerns::ReflectionMemory::Store do
  subject(:store) { described_class.new(max_size:) }

  let(:max_size) { 10 }

  def make_reflection(task:, outcome: :failure)
    Smolagents::Types::Reflection.new(
      task:,
      action: "test_action",
      outcome:,
      observation: "test observation",
      reflection: "test reflection",
      timestamp: Time.now
    )
  end

  describe "#initialize" do
    it "creates an empty store" do
      expect(store.size).to eq(0)
    end

    it "accepts max_size parameter" do
      custom_store = described_class.new(max_size: 5)
      expect(custom_store.size).to eq(0)
    end
  end

  describe "#add" do
    it "stores a reflection" do
      reflection = make_reflection(task: "task_001")

      result = store.add(reflection)

      expect(result).to eq(reflection)
      expect(store.size).to eq(1)
    end

    it "maintains bounded memory via LRU eviction" do
      small_store = described_class.new(max_size: 3)

      5.times { |i| small_store.add(make_reflection(task: "task_#{i}")) }

      expect(small_store.size).to eq(3)
    end

    it "evicts oldest entries when at capacity" do
      small_store = described_class.new(max_size: 2)
      first = make_reflection(task: "first")
      second = make_reflection(task: "second")
      third = make_reflection(task: "third")

      small_store.add(first)
      small_store.add(second)
      small_store.add(third)

      tasks = small_store.all.map(&:task)
      expect(tasks).not_to include("first")
      expect(tasks).to include("second", "third")
    end
  end

  describe "#all" do
    it "returns all stored reflections" do
      r1 = make_reflection(task: "a")
      r2 = make_reflection(task: "b")
      store.add(r1)
      store.add(r2)

      expect(store.all).to contain_exactly(r1, r2)
    end

    it "returns a duplicate array (not the internal one)" do
      store.add(make_reflection(task: "test"))

      result = store.all
      result.clear

      expect(store.size).to eq(1)
    end
  end

  describe "#relevant_to" do
    it "returns failure reflections sorted by task similarity" do
      store.add(make_reflection(task: "ruby programming", outcome: :failure))
      store.add(make_reflection(task: "python coding", outcome: :failure))
      store.add(make_reflection(task: "ruby coding basics", outcome: :failure))

      results = store.relevant_to("ruby coding")

      expect(results.first.task).to include("ruby")
    end

    it "excludes success reflections" do
      store.add(make_reflection(task: "test task", outcome: :success))
      store.add(make_reflection(task: "test task", outcome: :failure))

      results = store.relevant_to("test task")

      expect(results.size).to eq(1)
      expect(results.first.failure?).to be true
    end

    it "respects the limit parameter" do
      5.times { |i| store.add(make_reflection(task: "task #{i}", outcome: :failure)) }

      results = store.relevant_to("task", limit: 2)

      expect(results.size).to eq(2)
    end
  end

  describe "#failures" do
    it "returns only failure reflections" do
      store.add(make_reflection(task: "task1", outcome: :failure))
      store.add(make_reflection(task: "task2", outcome: :success))
      store.add(make_reflection(task: "task3", outcome: :failure))

      failures = store.failures

      expect(failures.size).to eq(2)
      expect(failures).to all(be_failure)
    end
  end

  describe "#clear" do
    it "removes all reflections" do
      store.add(make_reflection(task: "task"))
      expect(store.size).to eq(1)

      store.clear

      expect(store.size).to eq(0)
    end
  end

  describe "#size" do
    it "returns the number of stored reflections" do
      expect(store.size).to eq(0)

      store.add(make_reflection(task: "task1"))
      expect(store.size).to eq(1)

      store.add(make_reflection(task: "task2"))
      expect(store.size).to eq(2)
    end
  end

  describe "thread safety" do
    it "handles concurrent access safely" do
      threads = Array.new(10) do |i|
        Thread.new { store.add(make_reflection(task: "task_#{i}")) }
      end
      threads.each(&:join)

      expect(store.size).to eq(10)
    end
  end
end
