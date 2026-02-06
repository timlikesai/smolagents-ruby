require "spec_helper"

RSpec.describe Smolagents::Testing::ModelBenchmark::Aggregator do
  # Create a test class that includes the Aggregator module
  let(:test_class) do
    Class.new do
      include Smolagents::Testing::ModelBenchmark::Aggregator

      attr_accessor :logger

      def initialize
        @logger = Logger.new(nil)
      end

      # Mock run_test to return controlled results
      def run_test(model_id, test, timeout:)
        @test_results&.shift || build_success(model_id, test)
      end

      def prepare_results(results)
        @test_results = results.dup
      end

      private

      def build_success(model_id, test)
        Smolagents::Testing::BenchmarkResult.success(
          model_id:,
          test_name: test[:name],
          level: test[:level],
          duration: 1.0,
          tokens: Smolagents::Types::TokenUsage.new(input_tokens: 100, output_tokens: 50)
        )
      end
    end
  end

  let(:aggregator) { test_class.new }
  let(:test_definition) { { name: "test_case", level: 3 } }

  describe "#run_test_with_retries" do
    context "with single run" do
      it "delegates directly to run_test" do
        result = aggregator.run_test_with_retries(
          "test-model",
          test_definition,
          timeout: 30,
          runs: 1,
          pass_threshold: 0.5
        )

        expect(result).to be_a(Smolagents::Testing::BenchmarkResult)
        expect(result.passed?).to be true
      end
    end

    context "with multiple runs" do
      it "aggregates all passing results as success" do
        passing_results = Array.new(3) do
          Smolagents::Testing::BenchmarkResult.success(
            model_id: "test-model",
            test_name: "test_case",
            level: 3,
            duration: 1.0 + rand,
            tokens: Smolagents::Types::TokenUsage.new(input_tokens: 100, output_tokens: 50)
          )
        end
        aggregator.prepare_results(passing_results)

        result = aggregator.run_test_with_retries(
          "test-model",
          test_definition,
          timeout: 30,
          runs: 3,
          pass_threshold: 0.5
        )

        expect(result.passed?).to be true
        expect(result.metadata[:runs]).to eq(3)
        expect(result.metadata[:passed_runs]).to eq(3)
        expect(result.metadata[:pass_rate]).to eq(1.0)
      end

      it "aggregates mixed results based on threshold" do
        mixed_results = [
          Smolagents::Testing::BenchmarkResult.success(
            model_id: "test-model", test_name: "test_case", level: 3, duration: 1.0,
            tokens: Smolagents::Types::TokenUsage.new(input_tokens: 100, output_tokens: 50)
          ),
          Smolagents::Testing::BenchmarkResult.success(
            model_id: "test-model", test_name: "test_case", level: 3, duration: 1.5,
            tokens: Smolagents::Types::TokenUsage.new(input_tokens: 100, output_tokens: 50)
          ),
          Smolagents::Testing::BenchmarkResult.failure(
            model_id: "test-model", test_name: "test_case", level: 3, duration: 2.0,
            error: "Timeout", tokens: Smolagents::Types::TokenUsage.new(input_tokens: 50, output_tokens: 25)
          )
        ]
        aggregator.prepare_results(mixed_results)

        # 2/3 = 0.667 > 0.5 threshold -> pass
        result = aggregator.run_test_with_retries(
          "test-model",
          test_definition,
          timeout: 30,
          runs: 3,
          pass_threshold: 0.5
        )

        expect(result.passed?).to be true
        expect(result.metadata[:passed_runs]).to eq(2)
        expect(result.metadata[:pass_rate]).to be_within(0.001).of(0.667)
      end

      it "fails when pass rate below threshold" do
        failing_results = [
          Smolagents::Testing::BenchmarkResult.success(
            model_id: "test-model", test_name: "test_case", level: 3, duration: 1.0,
            tokens: Smolagents::Types::TokenUsage.new(input_tokens: 100, output_tokens: 50)
          ),
          Smolagents::Testing::BenchmarkResult.failure(
            model_id: "test-model", test_name: "test_case", level: 3, duration: 2.0,
            error: "Error 1", tokens: Smolagents::Types::TokenUsage.new(input_tokens: 50, output_tokens: 25)
          ),
          Smolagents::Testing::BenchmarkResult.failure(
            model_id: "test-model", test_name: "test_case", level: 3, duration: 2.0,
            error: "Error 2", tokens: Smolagents::Types::TokenUsage.new(input_tokens: 50, output_tokens: 25)
          )
        ]
        aggregator.prepare_results(failing_results)

        # 1/3 = 0.333 < 0.5 threshold -> fail
        result = aggregator.run_test_with_retries(
          "test-model",
          test_definition,
          timeout: 30,
          runs: 3,
          pass_threshold: 0.5
        )

        expect(result.passed?).to be false
        expect(result.metadata[:passed_runs]).to eq(1)
        expect(result.error).to include("1/3 passed")
      end

      it "includes durations in metadata" do
        results = [1.5, 2.0, 1.0].map do |dur|
          Smolagents::Testing::BenchmarkResult.success(
            model_id: "test-model", test_name: "test_case", level: 3, duration: dur,
            tokens: Smolagents::Types::TokenUsage.new(input_tokens: 100, output_tokens: 50)
          )
        end
        aggregator.prepare_results(results)

        result = aggregator.run_test_with_retries(
          "test-model",
          test_definition,
          timeout: 30,
          runs: 3,
          pass_threshold: 0.5
        )

        expect(result.metadata[:durations]).to eq([1.5, 2.0, 1.0])
      end

      it "sums tokens across all attempts" do
        results = Array.new(3) do |i|
          Smolagents::Testing::BenchmarkResult.success(
            model_id: "test-model", test_name: "test_case", level: 3, duration: 1.0,
            tokens: Smolagents::Types::TokenUsage.new(input_tokens: 100 * (i + 1), output_tokens: 50 * (i + 1))
          )
        end
        aggregator.prepare_results(results)

        result = aggregator.run_test_with_retries(
          "test-model",
          test_definition,
          timeout: 30,
          runs: 3,
          pass_threshold: 0.5
        )

        # (100+200+300, 50+100+150) = (600, 300)
        expect(result.tokens.input_tokens).to eq(600)
        expect(result.tokens.output_tokens).to eq(300)
      end

      it "selects fastest passing result as representative for success" do
        results = [
          Smolagents::Testing::BenchmarkResult.success(
            model_id: "test-model", test_name: "test_case", level: 3, duration: 2.0, steps: 3,
            tokens: Smolagents::Types::TokenUsage.new(input_tokens: 100, output_tokens: 50)
          ),
          Smolagents::Testing::BenchmarkResult.success(
            model_id: "test-model", test_name: "test_case", level: 3, duration: 1.0, steps: 2,
            tokens: Smolagents::Types::TokenUsage.new(input_tokens: 100, output_tokens: 50)
          ),
          Smolagents::Testing::BenchmarkResult.success(
            model_id: "test-model", test_name: "test_case", level: 3, duration: 1.5, steps: 4,
            tokens: Smolagents::Types::TokenUsage.new(input_tokens: 100, output_tokens: 50)
          )
        ]
        aggregator.prepare_results(results)

        result = aggregator.run_test_with_retries(
          "test-model",
          test_definition,
          timeout: 30,
          runs: 3,
          pass_threshold: 0.5
        )

        # Fastest passing result had steps: 2
        expect(result.steps).to eq(2)
      end

      it "collects unique errors from failed attempts" do
        results = [
          Smolagents::Testing::BenchmarkResult.failure(
            model_id: "test-model", test_name: "test_case", level: 3, duration: 1.0,
            error: "Timeout", tokens: Smolagents::Types::TokenUsage.new(input_tokens: 50, output_tokens: 25)
          ),
          Smolagents::Testing::BenchmarkResult.failure(
            model_id: "test-model", test_name: "test_case", level: 3, duration: 1.0,
            error: "Validation failed", tokens: Smolagents::Types::TokenUsage.new(input_tokens: 50, output_tokens: 25)
          ),
          Smolagents::Testing::BenchmarkResult.failure(
            model_id: "test-model", test_name: "test_case", level: 3, duration: 1.0,
            error: "Timeout", tokens: Smolagents::Types::TokenUsage.new(input_tokens: 50, output_tokens: 25)
          )
        ]
        aggregator.prepare_results(results)

        result = aggregator.run_test_with_retries(
          "test-model",
          test_definition,
          timeout: 30,
          runs: 3,
          pass_threshold: 0.5
        )

        expect(result.error).to include("Timeout")
        expect(result.error).to include("Validation failed")
      end
    end
  end
end
