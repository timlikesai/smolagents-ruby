require "smolagents/testing"

RSpec.describe Smolagents::Testing::RequirementBuilder do
  describe "initialization" do
    it "creates builder with name" do
      builder = described_class.new("my_agent")

      expect(builder.all_test_cases).to eq([])
    end

    it "defaults reliability to single run with 100% threshold" do
      builder = described_class.new("my_agent")
      suite = builder.build

      expect(suite.reliability).to eq({ runs: 1, threshold: 1.0 })
    end
  end

  describe "#requires" do
    it "adds all tests for a capability" do
      builder = described_class.new("agent")
                               .requires(:tool_use)

      # The existing Capabilities module has :single_tool and :multi_tool for :tool_use
      capabilities = builder.all_test_cases.map(&:capability).uniq
      expect(capabilities).to eq([:tool_use])
      expect(builder.all_test_cases.size).to eq(2)
    end

    it "supports chaining multiple requires" do
      builder = described_class.new("agent")
                               .requires(:tool_use)
                               .requires(:reasoning)

      capabilities = builder.all_test_cases.map(&:capability).uniq
      expect(capabilities).to contain_exactly(:tool_use, :reasoning)
    end

    it "applies max_steps constraint" do
      builder = described_class.new("agent")
                               .requires(:text, max: 10)

      tests = builder.all_test_cases
      expect(tests.size).to eq(1)
      expect(tests.first.max_steps).to eq(10)
    end

    it "does not modify original test case" do
      original_test = Smolagents::Testing::Capabilities.get(:basic_response)
      original_max_steps = original_test.max_steps

      described_class.new("agent")
                     .requires(:text, max: 99)

      # Original unchanged
      expect(original_test.max_steps).to eq(original_max_steps)
    end

    it "returns empty array for unknown capability" do
      builder = described_class.new("agent")
                               .requires(:unknown_capability_xyz)

      expect(builder.all_test_cases).to eq([])
    end

    it "returns self for chaining" do
      builder = described_class.new("agent")
      result = builder.requires(:text)

      expect(result).to be(builder)
    end
  end

  describe "#requires_test" do
    it "adds a specific test by name" do
      builder = described_class.new("agent")
                               .requires_test(:single_tool)

      expect(builder.all_test_cases.size).to eq(1)
      expect(builder.all_test_cases.first.name).to eq("single_tool")
    end

    it "applies constraints to the test" do
      builder = described_class.new("agent")
                               .requires_test(:basic_response, max_steps: 15, timeout: 120)

      tests = builder.all_test_cases
      expect(tests.first.max_steps).to eq(15)
      expect(tests.first.timeout).to eq(120)
    end

    it "raises KeyError for unknown test" do
      builder = described_class.new("agent")

      expect { builder.requires_test(:nonexistent_test_xyz) }.to raise_error(KeyError)
    end

    it "returns self for chaining" do
      builder = described_class.new("agent")
      result = builder.requires_test(:basic_response)

      expect(result).to be(builder)
    end
  end

  describe "#test" do
    it "adds a custom test" do
      builder = described_class.new("agent")
                               .test("custom_test") do |t|
                                 t.capability(:custom)
                                 t.task("Do something custom")
      end

      tests = builder.all_test_cases
      expect(tests.size).to eq(1)
      expect(tests.first.name).to eq("custom_test")
      expect(tests.first.capability).to eq(:custom)
      expect(tests.first.task).to eq("Do something custom")
    end

    it "configures all test case attributes" do
      validator = ->(r) { r.include?("expected") }

      builder = described_class.new("agent")
                               .test("full_test") do |t|
                                 t.capability(:full)
                                 t.task("Full task")
                                 t.tools(:search, :web)
                                 t.validator(validator)
                                 t.max_steps(10)
                                 t.timeout(120)
      end

      test = builder.all_test_cases.first
      expect(test.capability).to eq(:full)
      expect(test.task).to eq("Full task")
      expect(test.tools).to eq(%i[search web])
      expect(test.validator).to eq(validator)
      expect(test.max_steps).to eq(10)
      expect(test.timeout).to eq(120)
    end

    it "uses defaults when block is minimal" do
      builder = described_class.new("agent")
                               .test("minimal_test") { nil }

      test = builder.all_test_cases.first
      expect(test.capability).to eq(:custom)
      expect(test.task).to eq("")
      expect(test.tools).to eq([])
      expect(test.validator).to be_nil
      expect(test.max_steps).to eq(5)
      expect(test.timeout).to eq(60)
    end

    it "returns self for chaining" do
      builder = described_class.new("agent")
      result = builder.test("test") { nil }

      expect(result).to be(builder)
    end
  end

  describe "#reliability" do
    it "sets reliability configuration" do
      builder = described_class.new("agent")
                               .reliability(runs: 3, threshold: 0.8)

      suite = builder.build
      expect(suite.reliability).to eq({ runs: 3, threshold: 0.8 })
    end

    it "returns self for chaining" do
      builder = described_class.new("agent")
      result = builder.reliability(runs: 2, threshold: 0.5)

      expect(result).to be(builder)
    end
  end

  describe "#all_test_cases" do
    it "combines requirements and custom tests" do
      builder = described_class.new("agent")
                               .requires(:text)
                               .test("custom") { |t| t.task("Custom task") }

      tests = builder.all_test_cases
      expect(tests.size).to eq(2)
      expect(tests.first.name).to eq("basic_response")
      expect(tests.last.name).to eq("custom")
    end
  end

  describe "#build" do
    it "creates a TestSuite" do
      builder = described_class.new("my_suite")
                               .requires(:text)
                               .reliability(runs: 2, threshold: 0.7)

      suite = builder.build

      expect(suite).to be_a(Smolagents::Testing::TestSuite)
      expect(suite.name).to eq("my_suite")
      expect(suite.test_cases.size).to eq(1)
      expect(suite.reliability).to eq({ runs: 2, threshold: 0.7 })
    end
  end

  describe "#rank_models" do
    let(:test_case) do
      Smolagents::Testing::Capabilities.get(:basic_response)
    end

    let(:passing_result) do
      Smolagents::Testing::TestResult.new(
        test_case:,
        passed: true,
        output: "success"
      )
    end

    let(:failing_result) do
      Smolagents::Testing::TestResult.new(
        test_case:,
        passed: false,
        error: RuntimeError.new("failed")
      )
    end

    it "ranks models by pass rate" do
      builder = described_class.new("agent")
                               .requires(:text)

      model_a = double(model_id: "model_a")
      model_b = double(model_id: "model_b")

      scores = builder.rank_models([model_a, model_b]) do |_test, model|
        if model.model_id == "model_a"
          passing_result
        else
          failing_result
        end
      end

      expect(scores.first.model_id).to eq("model_a")
      expect(scores.first.pass_rate).to eq(1.0)
      expect(scores.last.model_id).to eq("model_b")
      expect(scores.last.pass_rate).to eq(0.0)
    end

    it "tracks capabilities passed" do
      Smolagents::Testing::Capabilities.get(:single_tool)
      Smolagents::Testing::Capabilities.get(:reasoning)

      builder = described_class.new("agent")
                               .requires_test(:single_tool)
                               .requires_test(:reasoning)

      model = double(model_id: "test_model")

      scores = builder.rank_models([model]) do |test, _model|
        if test.capability == :tool_use
          Smolagents::Testing::TestResult.new(test_case: test, passed: true)
        else
          Smolagents::Testing::TestResult.new(test_case: test, passed: false)
        end
      end

      score = scores.first
      expect(score.passed?(:tool_use)).to be true
      expect(score.passed?(:reasoning)).to be false
    end

    it "handles models without model_id method" do
      builder = described_class.new("agent")
                               .requires(:text)

      scores = builder.rank_models(["string_model"]) do |_test, _model|
        passing_result
      end

      expect(scores.first.model_id).to eq("string_model")
    end

    it "includes all results in score" do
      builder = described_class.new("agent")
                               .requires_test(:single_tool)
                               .requires_test(:reasoning)

      model = double(model_id: "test")

      scores = builder.rank_models([model]) do |test, _|
        Smolagents::Testing::TestResult.new(test_case: test, passed: true)
      end

      expect(scores.first.results.size).to eq(2)
    end
  end

  describe "fluent chaining" do
    it "supports full fluent API" do
      builder = described_class.new("full_example")
                               .requires(:text)
                               .test("extra") { |t| t.task("Extra task") }
                               .reliability(runs: 3, threshold: 0.67)

      suite = builder.build

      expect(suite.name).to eq("full_example")
      expect(suite.test_cases.size).to eq(2)
      expect(suite.reliability[:runs]).to eq(3)
    end
  end
end

RSpec.describe Smolagents::Testing::TestSuite do
  it "is a Data.define type" do
    suite = described_class.new(
      name: "test_suite",
      test_cases: [],
      reliability: { runs: 1, threshold: 1.0 }
    )

    expect(suite).to be_frozen
  end

  it "stores all attributes" do
    tests = [
      Smolagents::Testing::TestCase.new(
        name: "test",
        capability: :basic,
        task: "task"
      )
    ]

    suite = described_class.new(
      name: "my_suite",
      test_cases: tests,
      reliability: { runs: 2, threshold: 0.5 }
    )

    expect(suite.name).to eq("my_suite")
    expect(suite.test_cases).to eq(tests)
    expect(suite.reliability).to eq({ runs: 2, threshold: 0.5 })
  end
end

RSpec.describe Smolagents::Testing::ModelScore do
  let(:test_case) do
    Smolagents::Testing::TestCase.new(
      name: "test",
      capability: :tool_use,
      task: "task"
    )
  end

  let(:result) do
    Smolagents::Testing::TestResult.new(
      test_case:,
      passed: true
    )
  end

  it "stores all attributes" do
    score = described_class.new(
      model_id: "gpt-4",
      capabilities_passed: %i[tool_use reasoning],
      pass_rate: 0.9,
      results: [result]
    )

    expect(score.model_id).to eq("gpt-4")
    expect(score.capabilities_passed).to eq(%i[tool_use reasoning])
    expect(score.pass_rate).to eq(0.9)
    expect(score.results).to eq([result])
  end

  describe "#passed?" do
    it "returns true for passed capabilities" do
      score = described_class.new(
        model_id: "test",
        capabilities_passed: %i[tool_use vision],
        pass_rate: 1.0,
        results: []
      )

      expect(score.passed?(:tool_use)).to be true
      expect(score.passed?(:vision)).to be true
    end

    it "returns false for capabilities not passed" do
      score = described_class.new(
        model_id: "test",
        capabilities_passed: [:tool_use],
        pass_rate: 0.5,
        results: []
      )

      expect(score.passed?(:reasoning)).to be false
    end
  end
end

RSpec.describe Smolagents::Testing::TestCaseBuilder do
  describe "initialization" do
    it "sets name and defaults" do
      builder = described_class.new("my_test")
      test = builder.build

      expect(test.name).to eq("my_test")
      expect(test.capability).to eq(:custom)
      expect(test.task).to eq("")
      expect(test.tools).to eq([])
      expect(test.validator).to be_nil
      expect(test.max_steps).to eq(5)
      expect(test.timeout).to eq(60)
    end
  end

  describe "fluent setters" do
    it "sets capability" do
      test = described_class.new("test")
                            .capability(:tool_use)
                            .build

      expect(test.capability).to eq(:tool_use)
    end

    it "sets task" do
      test = described_class.new("test")
                            .task("Do something")
                            .build

      expect(test.task).to eq("Do something")
    end

    it "sets tools" do
      test = described_class.new("test")
                            .tools(:search, :web)
                            .build

      expect(test.tools).to eq(%i[search web])
    end

    it "sets validator" do
      validator = lambda(&:success?)
      test = described_class.new("test")
                            .validator(validator)
                            .build

      expect(test.validator).to eq(validator)
    end

    it "sets max_steps" do
      test = described_class.new("test")
                            .max_steps(10)
                            .build

      expect(test.max_steps).to eq(10)
    end

    it "sets timeout" do
      test = described_class.new("test")
                            .timeout(120)
                            .build

      expect(test.timeout).to eq(120)
    end

    it "supports chaining all setters" do
      validator = ->(r) { r.include?("ok") }

      test = described_class.new("chained")
                            .capability(:reasoning)
                            .task("Think about this")
                            .tools(:calculator)
                            .validator(validator)
                            .max_steps(8)
                            .timeout(90)
                            .build

      expect(test.name).to eq("chained")
      expect(test.capability).to eq(:reasoning)
      expect(test.task).to eq("Think about this")
      expect(test.tools).to eq([:calculator])
      expect(test.validator).to eq(validator)
      expect(test.max_steps).to eq(8)
      expect(test.timeout).to eq(90)
    end
  end

  describe "#build" do
    it "returns a TestCase" do
      builder = described_class.new("test")
      result = builder.build

      expect(result).to be_a(Smolagents::Testing::TestCase)
    end

    it "creates immutable TestCase" do
      builder = described_class.new("test")
      result = builder.build

      expect(result).to be_frozen
    end
  end
end
