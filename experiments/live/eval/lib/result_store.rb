# Result Store
#
# Persists test results to JSON files organized by model and suite.
# Enables historical comparison and progress tracking.

require "json"
require "fileutils"

module LiveExperiments
  module Eval
    class ResultStore
      RESULTS_DIR = File.expand_path("../results", __dir__)

      def initialize(base_dir: RESULTS_DIR)
        @base_dir = base_dir
      end

      # Store a result set
      def store(result)
        dir = result_dir(result.model_id, result.suite_name)
        FileUtils.mkdir_p(dir)

        path = File.join(dir, "#{result.timestamp.strftime("%Y%m%d_%H%M%S")}.json")
        File.write(path, JSON.pretty_generate(result.to_h))
        path
      end

      # Get latest result for a model/suite combination
      def latest(model_id, suite_name)
        dir = result_dir(model_id, suite_name)
        return nil unless Dir.exist?(dir)

        files = Dir.glob(File.join(dir, "*.json")).sort.last
        return nil unless files

        parse_result(files)
      end

      # Get all results for a model/suite
      def history(model_id, suite_name)
        dir = result_dir(model_id, suite_name)
        return [] unless Dir.exist?(dir)

        Dir.glob(File.join(dir, "*.json")).sort.map { |f| parse_result(f) }
      end

      # Get all models that have results for a suite
      def models_for_suite(suite_name)
        Dir.glob(File.join(@base_dir, "*/#{suite_name}")).map do |path|
          File.basename(File.dirname(path))
        end.sort
      end

      # Get all suites that have results
      def suites_with_results
        Dir.glob(File.join(@base_dir, "*/*")).map do |path|
          File.basename(path)
        end.uniq.sort
      end

      # Check if model has results for suite
      def has_results?(model_id, suite_name)
        Dir.exist?(result_dir(model_id, suite_name)) &&
          Dir.glob(File.join(result_dir(model_id, suite_name), "*.json")).any?
      end

      private

      def result_dir(model_id, suite_name)
        # Sanitize model_id for filesystem
        safe_model_id = model_id.gsub(%r{[/\\:]}, "_")
        File.join(@base_dir, safe_model_id, suite_name)
      end

      def parse_result(path)
        data = JSON.parse(File.read(path), symbolize_names: true)
        SuiteResult.new(
          model_id: data[:model_id],
          suite_name: data[:suite_name],
          timestamp: Time.parse(data[:timestamp]),
          summary: ResultSummary.new(**data[:summary]),
          test_results: data[:test_results].map { |tr| TestResult.new(**tr) },
          metadata: data[:metadata] || {}
        )
      end
    end

    # Complete result for a suite run
    SuiteResult = Data.define(:model_id, :suite_name, :timestamp, :summary, :test_results, :metadata) do
      def to_h
        {
          model_id:,
          suite_name:,
          timestamp: timestamp.iso8601,
          summary: summary.to_h,
          test_results: test_results.map(&:to_h),
          metadata:
        }
      end
    end

    # Summary statistics
    ResultSummary = Data.define(:total, :passed, :failed, :skipped, :pass_rate, :avg_duration_ms) do
      def to_h
        { total:, passed:, failed:, skipped:, pass_rate:, avg_duration_ms: }
      end
    end

    # Individual test result
    TestResult = Data.define(:test_id, :test_name, :passed, :duration_ms, :output, :error, :details) do
      def initialize(test_id:, test_name:, passed:, duration_ms:, output: nil, error: nil, details: {})
        super
      end

      def to_h
        { test_id:, test_name:, passed:, duration_ms:, output:, error:, details: }
      end
    end
  end
end
