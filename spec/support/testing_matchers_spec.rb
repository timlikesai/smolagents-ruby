RSpec.describe Smolagents::Testing::Matchers do
  let(:test_case) do
    Smolagents::Testing::TestCase.new(
      name: "example",
      capability: :tool_use,
      task: "Do something",
      max_steps: 10
    )
  end

  describe "be_passed" do
    context "with TestResult" do
      it "matches when passed is true" do
        result = Smolagents::Testing::TestResult.new(
          test_case:,
          passed: true,
          steps: 3
        )
        expect(result).to be_passed
      end

      it "does not match when passed is false" do
        result = Smolagents::Testing::TestResult.new(
          test_case:,
          passed: false,
          error: StandardError.new("Test failed")
        )
        expect(result).not_to be_passed
      end

      it "provides helpful failure message" do
        result = Smolagents::Testing::TestResult.new(
          test_case:,
          passed: false,
          error: StandardError.new("Something went wrong")
        )
        matcher = be_passed
        matcher.matches?(result)
        expect(matcher.failure_message).to include("Something went wrong")
      end
    end

    context "with TestRun" do
      it "matches when pass_rate meets threshold" do
        results = [
          Smolagents::Testing::TestResult.new(test_case:, passed: true),
          Smolagents::Testing::TestResult.new(test_case:, passed: true)
        ]
        run = Smolagents::Testing::TestRun.new(
          test_case:,
          results:,
          threshold: 1.0
        )
        expect(run).to be_passed
      end

      it "does not match when pass_rate below threshold" do
        results = [
          Smolagents::Testing::TestResult.new(test_case:, passed: true),
          Smolagents::Testing::TestResult.new(test_case:, passed: false)
        ]
        run = Smolagents::Testing::TestRun.new(
          test_case:,
          results:,
          threshold: 1.0
        )
        expect(run).not_to be_passed
      end

      it "provides helpful failure message with pass_rate" do
        results = [
          Smolagents::Testing::TestResult.new(test_case:, passed: false)
        ]
        run = Smolagents::Testing::TestRun.new(
          test_case:,
          results:,
          threshold: 1.0
        )
        matcher = be_passed
        matcher.matches?(run)
        expect(matcher.failure_message).to include("pass_rate")
        expect(matcher.failure_message).to include("threshold")
      end
    end
  end

  describe "have_pass_rate" do
    let(:results) do
      [
        Smolagents::Testing::TestResult.new(test_case:, passed: true),
        Smolagents::Testing::TestResult.new(test_case:, passed: true),
        Smolagents::Testing::TestResult.new(test_case:, passed: false),
        Smolagents::Testing::TestResult.new(test_case:, passed: false)
      ]
    end

    let(:run) do
      Smolagents::Testing::TestRun.new(test_case:, results:, threshold: 0.5)
    end

    it "matches with at_least when pass_rate is sufficient" do
      expect(run).to have_pass_rate(at_least: 0.5)
      expect(run).to have_pass_rate(at_least: 0.4)
    end

    it "does not match with at_least when pass_rate is insufficient" do
      expect(run).not_to have_pass_rate(at_least: 0.6)
    end

    it "matches with exactly when pass_rate equals" do
      expect(run).to have_pass_rate(exactly: 0.5)
    end

    it "does not match with exactly when pass_rate differs" do
      expect(run).not_to have_pass_rate(exactly: 0.6)
    end

    it "matches with at_most when pass_rate is below or equal" do
      expect(run).to have_pass_rate(at_most: 0.5)
      expect(run).to have_pass_rate(at_most: 0.6)
    end

    it "does not match with at_most when pass_rate exceeds" do
      expect(run).not_to have_pass_rate(at_most: 0.4)
    end

    it "defaults to at_least when given numeric value" do
      expect(run).to have_pass_rate(0.5)
      expect(run).not_to have_pass_rate(0.6)
    end

    it "provides helpful failure message" do
      matcher = have_pass_rate(at_least: 0.8)
      matcher.matches?(run)
      expect(matcher.failure_message).to include(">= 0.8")
      expect(matcher.failure_message).to include("0.5")
    end
  end

  describe "have_efficiency" do
    it "matches with above when efficiency exceeds threshold" do
      result = Smolagents::Testing::TestResult.new(
        test_case:,
        passed: true,
        steps: 3 # efficiency = 1 - 3/10 = 0.7
      )
      expect(result).to have_efficiency(above: 0.5)
    end

    it "does not match with above when efficiency is below" do
      result = Smolagents::Testing::TestResult.new(
        test_case:,
        passed: true,
        steps: 8 # efficiency = 1 - 8/10 = 0.2
      )
      expect(result).not_to have_efficiency(above: 0.5)
    end

    it "matches with below when efficiency is under threshold" do
      result = Smolagents::Testing::TestResult.new(
        test_case:,
        passed: true,
        steps: 9 # efficiency = 1 - 9/10 = 0.1
      )
      expect(result).to have_efficiency(below: 0.5)
    end

    it "defaults to at_least when given numeric value" do
      result = Smolagents::Testing::TestResult.new(
        test_case:,
        passed: true,
        steps: 3 # efficiency = 0.7
      )
      expect(result).to have_efficiency(0.7)
      expect(result).not_to have_efficiency(0.8)
    end

    it "returns 0.0 efficiency for failed tests" do
      result = Smolagents::Testing::TestResult.new(
        test_case:,
        passed: false,
        steps: 3
      )
      expect(result).not_to have_efficiency(above: 0.0)
    end
  end

  describe "have_completed_in" do
    it "matches exact step count" do
      result = Smolagents::Testing::TestResult.new(
        test_case:,
        passed: true,
        steps: 3
      )
      expect(result).to have_completed_in(steps: 3)
    end

    it "does not match when step count differs" do
      result = Smolagents::Testing::TestResult.new(
        test_case:,
        passed: true,
        steps: 5
      )
      expect(result).not_to have_completed_in(steps: 3)
    end

    it "matches range when step count is within range" do
      result = Smolagents::Testing::TestResult.new(
        test_case:,
        passed: true,
        steps: 3
      )
      expect(result).to have_completed_in(steps: 1..5)
    end

    it "does not match range when step count is outside" do
      result = Smolagents::Testing::TestResult.new(
        test_case:,
        passed: true,
        steps: 7
      )
      expect(result).not_to have_completed_in(steps: 1..5)
    end

    it "provides helpful failure message" do
      result = Smolagents::Testing::TestResult.new(
        test_case:,
        passed: true,
        steps: 7
      )
      matcher = have_completed_in(steps: 3)
      matcher.matches?(result)
      expect(matcher.failure_message).to include("3 steps")
      expect(matcher.failure_message).to include("got 7")
    end
  end

  describe "have_capability" do
    it "matches when capability is in capabilities_passed" do
      score = Smolagents::Testing::ModelScore.new(
        model_id: "test-model",
        capabilities_passed: %i[tool_use reasoning],
        pass_rate: 0.8,
        results: []
      )
      expect(score).to have_capability(:tool_use)
    end

    it "does not match when capability is not in capabilities_passed" do
      score = Smolagents::Testing::ModelScore.new(
        model_id: "test-model",
        capabilities_passed: [:tool_use],
        pass_rate: 0.8,
        results: []
      )
      expect(score).not_to have_capability(:vision)
    end

    it "provides helpful failure message" do
      score = Smolagents::Testing::ModelScore.new(
        model_id: "test-model",
        capabilities_passed: [:tool_use],
        pass_rate: 0.8,
        results: []
      )
      matcher = have_capability(:vision)
      matcher.matches?(score)
      expect(matcher.failure_message).to include("vision")
      expect(matcher.failure_message).to include("tool_use")
    end
  end
end
