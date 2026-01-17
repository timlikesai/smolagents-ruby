require "spec_helper"
require "smolagents/testing/test_case"
require "smolagents/testing/test_result"
require "smolagents/testing/test_run"
require "smolagents/testing/result_store"
require "tmpdir"

RSpec.describe Smolagents::Testing::ResultStore do
  let(:tmp_dir) { Dir.mktmpdir("result_store_test") }
  let(:store) { described_class.new(path: tmp_dir) }

  after { FileUtils.rm_rf(tmp_dir) }

  # Helper to build test fixtures
  def make_test_case(name:, capability: :reasoning)
    Smolagents::Testing::TestCase.new(
      name:,
      capability:,
      task: "Test task for #{name}"
    )
  end

  def make_test_result(test_case, passed: true)
    Smolagents::Testing::TestResult.new(
      test_case:,
      passed:,
      output: "Test output",
      duration: 1.5,
      steps: 3,
      tokens: 100
    )
  end

  def make_test_run(test_case, results: nil)
    results ||= [make_test_result(test_case)]
    Smolagents::Testing::TestRun.new(test_case:, results:)
  end

  describe ".new" do
    it "creates the directory if it does not exist" do
      new_path = File.join(tmp_dir, "nested", "results")
      described_class.new(path: new_path)

      expect(File.directory?(new_path)).to be true
    end

    it "accepts an existing directory" do
      expect { described_class.new(path: tmp_dir) }.not_to raise_error
    end
  end

  describe "#store" do
    let(:test_case) { make_test_case(name: "arithmetic_test", capability: :basic_reasoning) }
    let(:test_run) { make_test_run(test_case) }

    it "stores a test run and returns the data" do
      timestamp = Time.new(2024, 1, 15, 10, 30, 0, "+00:00")
      data = store.store(run: test_run, model_id: "gpt-4", timestamp:)

      expect(data[:model_id]).to eq("gpt-4")
      expect(data[:timestamp]).to eq(timestamp.iso8601)
      expect(data[:test_case][:name]).to eq("arithmetic_test")
      expect(data[:summary][:pass_rate]).to eq(1.0)
      expect(data[:results]).to be_an(Array)
    end

    it "writes a JSON file to disk" do
      store.store(run: test_run, model_id: "gpt-4")

      files = Dir.glob(File.join(tmp_dir, "**/*.json"))
      expect(files.size).to eq(1)
      expect(files.first).to include("gpt-4")
    end

    it "sanitizes model IDs in paths" do
      store.store(run: test_run, model_id: "model/with:special@chars")

      files = Dir.glob(File.join(tmp_dir, "**/*.json"))
      expect(files.first).to include("model_with_special_chars")
    end

    it "uses current time as default timestamp" do
      Timecop.freeze(Time.utc(2024, 6, 1, 12, 0, 0)) do
        data = store.store(run: test_run, model_id: "gpt-4")
        expect(data[:timestamp]).to eq("2024-06-01T12:00:00Z")
      end
    end
  end

  describe "#find_by_model" do
    before do
      tc1 = make_test_case(name: "test1")
      tc2 = make_test_case(name: "test2")
      store.store(run: make_test_run(tc1), model_id: "gpt-4")
      store.store(run: make_test_run(tc2), model_id: "gpt-4")
      store.store(run: make_test_run(tc1), model_id: "claude-3")
    end

    it "returns all results for the given model" do
      results = store.find_by_model("gpt-4")

      expect(results.size).to eq(2)
      expect(results.all? { |r| r[:model_id] == "gpt-4" }).to be true
    end

    it "returns empty array for unknown model" do
      results = store.find_by_model("unknown")

      expect(results).to eq([])
    end
  end

  describe "#find_by_capability" do
    before do
      tc1 = make_test_case(name: "reasoning_test", capability: :reasoning)
      tc2 = make_test_case(name: "tool_test", capability: :tool_use)
      store.store(run: make_test_run(tc1), model_id: "gpt-4")
      store.store(run: make_test_run(tc2), model_id: "gpt-4")
    end

    it "returns results matching the capability" do
      results = store.find_by_capability(:reasoning)

      expect(results.size).to eq(1)
      expect(results.first.dig(:test_case, :capability)).to eq("reasoning")
    end

    it "accepts string capability" do
      results = store.find_by_capability("tool_use")

      expect(results.size).to eq(1)
    end
  end

  describe "#find_by_test" do
    before do
      tc1 = make_test_case(name: "arithmetic_test")
      tc2 = make_test_case(name: "search_test")
      store.store(run: make_test_run(tc1), model_id: "gpt-4")
      store.store(run: make_test_run(tc1), model_id: "claude-3")
      store.store(run: make_test_run(tc2), model_id: "gpt-4")
    end

    it "returns all results for the given test name" do
      results = store.find_by_test("arithmetic_test")

      expect(results.size).to eq(2)
      expect(results.all? { |r| r.dig(:test_case, :name) == "arithmetic_test" }).to be true
    end

    it "accepts symbol test name" do
      results = store.find_by_test(:search_test)

      expect(results.size).to eq(1)
    end
  end

  describe "#all_results" do
    it "returns all stored results" do
      tc1 = make_test_case(name: "test1")
      tc2 = make_test_case(name: "test2")
      store.store(run: make_test_run(tc1), model_id: "gpt-4")
      store.store(run: make_test_run(tc2), model_id: "claude-3")

      results = store.all_results

      expect(results.size).to eq(2)
    end

    it "returns empty array when no results exist" do
      expect(store.all_results).to eq([])
    end

    it "skips invalid JSON files" do
      File.write(File.join(tmp_dir, "invalid.json"), "not valid json {")

      expect(store.all_results).to eq([])
    end
  end

  describe "#compare_models" do
    before do
      tc = make_test_case(name: "comparison_test")
      store.store(run: make_test_run(tc), model_id: "gpt-4")
      store.store(run: make_test_run(tc), model_id: "claude-3")
      store.store(run: make_test_run(tc), model_id: "llama-2")
    end

    it "returns results grouped by model" do
      comparison = store.compare_models("gpt-4", "claude-3")

      expect(comparison.keys).to contain_exactly("gpt-4", "claude-3")
      expect(comparison["gpt-4"].size).to eq(1)
      expect(comparison["claude-3"].size).to eq(1)
    end

    it "accepts array of model IDs" do
      comparison = store.compare_models(%w[gpt-4 llama-2])

      expect(comparison.keys).to contain_exactly("gpt-4", "llama-2")
    end

    it "includes empty array for models with no results" do
      comparison = store.compare_models("gpt-4", "unknown")

      expect(comparison["unknown"]).to eq([])
    end
  end

  describe "#regression?" do
    it "returns false when there is insufficient history" do
      tc = make_test_case(name: "regression_test")
      store.store(run: make_test_run(tc), model_id: "gpt-4")

      expect(store.regression?("gpt-4", "regression_test")).to be false
    end

    it "returns true when pass_rate drops significantly" do
      tc = make_test_case(name: "regression_test")

      # First run: 100% pass rate
      passing_results = [make_test_result(tc, passed: true)]
      run1 = Smolagents::Testing::TestRun.new(test_case: tc, results: passing_results)
      store.store(run: run1, model_id: "gpt-4", timestamp: Time.utc(2024, 1, 1))

      # Second run: 0% pass rate (regression)
      failing_results = [make_test_result(tc, passed: false)]
      run2 = Smolagents::Testing::TestRun.new(test_case: tc, results: failing_results)
      store.store(run: run2, model_id: "gpt-4", timestamp: Time.utc(2024, 1, 2))

      expect(store.regression?("gpt-4", "regression_test")).to be true
    end

    it "returns false when pass_rate stays stable" do
      tc = make_test_case(name: "stable_test")

      results = [make_test_result(tc, passed: true)]
      run = Smolagents::Testing::TestRun.new(test_case: tc, results:)
      store.store(run:, model_id: "gpt-4", timestamp: Time.utc(2024, 1, 1))
      store.store(run:, model_id: "gpt-4", timestamp: Time.utc(2024, 1, 2))

      expect(store.regression?("gpt-4", "stable_test")).to be false
    end

    it "respects custom threshold" do
      tc = make_test_case(name: "threshold_test")

      # First run: 100%
      passing = [make_test_result(tc, passed: true), make_test_result(tc, passed: true)]
      run1 = Smolagents::Testing::TestRun.new(test_case: tc, results: passing)
      store.store(run: run1, model_id: "gpt-4", timestamp: Time.utc(2024, 1, 1))

      # Second run: 50% (drop of 0.5)
      mixed = [make_test_result(tc, passed: true), make_test_result(tc, passed: false)]
      run2 = Smolagents::Testing::TestRun.new(test_case: tc, results: mixed)
      store.store(run: run2, model_id: "gpt-4", timestamp: Time.utc(2024, 1, 2))

      expect(store.regression?("gpt-4", "threshold_test", threshold: 0.6)).to be false
      expect(store.regression?("gpt-4", "threshold_test", threshold: 0.3)).to be true
    end
  end

  describe "#improvement?" do
    it "returns false when there is insufficient history" do
      tc = make_test_case(name: "improvement_test")
      store.store(run: make_test_run(tc), model_id: "gpt-4")

      expect(store.improvement?("gpt-4", "improvement_test")).to be false
    end

    it "returns true when pass_rate improves significantly" do
      tc = make_test_case(name: "improvement_test")

      # First run: 0%
      failing = [make_test_result(tc, passed: false)]
      run1 = Smolagents::Testing::TestRun.new(test_case: tc, results: failing)
      store.store(run: run1, model_id: "gpt-4", timestamp: Time.utc(2024, 1, 1))

      # Second run: 100%
      passing = [make_test_result(tc, passed: true)]
      run2 = Smolagents::Testing::TestRun.new(test_case: tc, results: passing)
      store.store(run: run2, model_id: "gpt-4", timestamp: Time.utc(2024, 1, 2))

      expect(store.improvement?("gpt-4", "improvement_test")).to be true
    end

    it "returns false when pass_rate stays the same" do
      tc = make_test_case(name: "stable_test")

      results = [make_test_result(tc, passed: true)]
      run = Smolagents::Testing::TestRun.new(test_case: tc, results:)
      store.store(run:, model_id: "gpt-4", timestamp: Time.utc(2024, 1, 1))
      store.store(run:, model_id: "gpt-4", timestamp: Time.utc(2024, 1, 2))

      expect(store.improvement?("gpt-4", "stable_test")).to be false
    end
  end

  describe "#trend" do
    it "returns :insufficient_data when there is only one result" do
      tc = make_test_case(name: "trend_test")
      store.store(run: make_test_run(tc), model_id: "gpt-4")

      expect(store.trend("gpt-4", "trend_test")).to eq(:insufficient_data)
    end

    it "returns :improving when pass_rate is increasing" do
      tc = make_test_case(name: "improving_test")

      # Series of improving results: 0%, 50%, 100%
      [0, 1, 2].each_with_index do |i, idx|
        results = (0...2).map { |j| make_test_result(tc, passed: j < i) }
        run = Smolagents::Testing::TestRun.new(test_case: tc, results:)
        store.store(run:, model_id: "gpt-4", timestamp: Time.utc(2024, 1, idx + 1))
      end

      expect(store.trend("gpt-4", "improving_test")).to eq(:improving)
    end

    it "returns :degrading when pass_rate is decreasing" do
      tc = make_test_case(name: "degrading_test")

      # Series of degrading results: 100%, 50%, 0%
      [2, 1, 0].each_with_index do |i, idx|
        results = (0...2).map { |j| make_test_result(tc, passed: j < i) }
        run = Smolagents::Testing::TestRun.new(test_case: tc, results:)
        store.store(run:, model_id: "gpt-4", timestamp: Time.utc(2024, 1, idx + 1))
      end

      expect(store.trend("gpt-4", "degrading_test")).to eq(:degrading)
    end

    it "returns :stable when pass_rate is constant" do
      tc = make_test_case(name: "stable_test")

      results = [make_test_result(tc, passed: true)]
      run = Smolagents::Testing::TestRun.new(test_case: tc, results:)

      3.times do |i|
        store.store(run:, model_id: "gpt-4", timestamp: Time.utc(2024, 1, i + 1))
      end

      expect(store.trend("gpt-4", "stable_test")).to eq(:stable)
    end

    it "respects window parameter" do
      tc = make_test_case(name: "window_test")

      # First 3 runs: degrading (100%, 50%, 0%)
      # Next 3 runs: stable at 0%
      [2, 1, 0, 0, 0, 0].each_with_index do |i, idx|
        results = (0...2).map { |j| make_test_result(tc, passed: j < i) }
        run = Smolagents::Testing::TestRun.new(test_case: tc, results:)
        store.store(run:, model_id: "gpt-4", timestamp: Time.utc(2024, 1, idx + 1))
      end

      # Full window shows degrading overall
      expect(store.trend("gpt-4", "window_test", window: 6)).to eq(:degrading)
      # Recent window shows stable
      expect(store.trend("gpt-4", "window_test", window: 3)).to eq(:stable)
    end
  end
end
