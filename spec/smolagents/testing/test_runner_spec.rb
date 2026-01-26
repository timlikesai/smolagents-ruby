require "smolagents/testing"

RSpec.describe Smolagents::Testing::TestRunner do
  let(:test_case) do
    Smolagents::Testing::TestCase.new(
      name: "arithmetic_test",
      capability: :basic_reasoning,
      task: "What is 2 + 2?",
      tools: [],
      validator: ->(result) { result.to_s.include?("4") },
      max_steps: 5,
      timeout: 60
    )
  end

  let(:mock_model) do
    model = Smolagents::Testing::MockModel.new
    model.queue_final_answer("4")
    model
  end

  describe "#initialize" do
    it "stores the test case" do
      runner = described_class.new(test_case, mock_model)

      expect(runner.test_case).to eq(test_case)
    end

    it "stores the model" do
      runner = described_class.new(test_case, mock_model)

      expect(runner.model).to eq(mock_model)
    end
  end

  describe "#run", :integration do
    it "returns a TestRun with single result by default" do
      runner = described_class.new(test_case, mock_model)
      run = runner.run

      expect(run).to be_a(Smolagents::Testing::TestRun)
      expect(run.results.size).to eq(1)
    end

    it "runs multiple times when specified" do
      model = Smolagents::Testing::MockModel.new
      3.times { model.queue_final_answer("4") }

      runner = described_class.new(test_case, model)
      run = runner.run(times: 3)

      expect(run.results.size).to eq(3)
    end

    it "passes threshold to TestRun" do
      runner = described_class.new(test_case, mock_model)
      run = runner.run(threshold: 0.8)

      expect(run.threshold).to eq(0.8)
    end

    it "includes the test case in the run" do
      runner = described_class.new(test_case, mock_model)
      run = runner.run

      expect(run.test_case).to eq(test_case)
    end
  end

  describe "result attributes", :integration do
    it "includes test_case in each result" do
      runner = described_class.new(test_case, mock_model)
      run = runner.run
      result = run.results.first

      expect(result.test_case).to eq(test_case)
    end

    it "measures duration" do
      runner = described_class.new(test_case, mock_model)
      run = runner.run
      result = run.results.first

      expect(result.duration).to be_a(Numeric)
    end
  end

  describe "validation", :integration do
    context "when validator returns true" do
      let(:passing_case) do
        Smolagents::Testing::TestCase.new(
          name: "passing_test",
          capability: :basic,
          task: "Say hello",
          validator: ->(r) { r.to_s.include?("hello") }
        )
      end

      it "marks the result as passed" do
        # The output will be exactly "hello world" when final_answer runs
        model = Smolagents::Testing::MockModel.new
        model.queue_final_answer("hello world")

        runner = described_class.new(passing_case, model)
        run = runner.run
        result = run.results.first

        expect(result.passed).to be true
      end
    end

    context "when validator returns false" do
      let(:failing_case) do
        Smolagents::Testing::TestCase.new(
          name: "failing_test",
          capability: :basic,
          task: "Say hello",
          validator: ->(r) { r.to_s.include?("goodbye") }
        )
      end

      it "marks the result as failed" do
        # Output will be "hello world", which doesn't include "goodbye"
        model = Smolagents::Testing::MockModel.new
        model.queue_final_answer("hello world")

        runner = described_class.new(failing_case, model)
        run = runner.run
        result = run.results.first

        expect(result.passed).to be false
      end
    end

    context "when no validator is provided" do
      let(:no_validator_case) do
        Smolagents::Testing::TestCase.new(
          name: "no_validator_test",
          capability: :basic,
          task: "Do something",
          validator: nil
        )
      end

      it "marks the result as passed" do
        model = Smolagents::Testing::MockModel.new
        model.queue_final_answer("anything")

        runner = described_class.new(no_validator_case, model)
        run = runner.run
        result = run.results.first

        expect(result.passed).to be true
      end
    end
  end

  describe "pass rate calculation", :integration do
    it "calculates pass rate across multiple runs" do
      # The output for "not 4" still contains "4" in "not 4"
      # Use different values to properly test
      model = Smolagents::Testing::MockModel.new
      model.queue_final_answer("4")
      model.queue_final_answer("nope")
      model.queue_final_answer("4")

      runner = described_class.new(test_case, model)
      run = runner.run(times: 3)

      # 2 out of 3 should pass (contain "4")
      expect(run.pass_rate).to be_within(0.01).of(0.67)
    end

    it "reports passed when meeting threshold" do
      model = Smolagents::Testing::MockModel.new
      4.times { model.queue_final_answer("4") }
      model.queue_final_answer("nope")

      runner = described_class.new(test_case, model)
      run = runner.run(times: 5, threshold: 0.8)

      expect(run.passed?).to be true
    end

    it "reports failed when below threshold" do
      model = Smolagents::Testing::MockModel.new
      2.times { model.queue_final_answer("4") }
      3.times { model.queue_final_answer("nope") }

      runner = described_class.new(test_case, model)
      run = runner.run(times: 5, threshold: 0.8)

      expect(run.failed?).to be true
    end
  end
end
