require_relative "result_store/persistence"
require_relative "result_store/querying"
require_relative "result_store/analysis"

module Smolagents
  module Testing
    # Persists and queries test results for model evaluation tracking.
    #
    # Stores test runs as JSON files organized by model ID, enabling historical
    # analysis and model comparison across test runs.
    #
    # @example Basic usage
    #   store = ResultStore.new(path: "test_results")
    #   store.store(run: test_run, model_id: "gpt-4")
    #
    # @example Querying results
    #   store.find_by_model("gpt-4")
    #   store.find_by_capability(:reasoning)
    #   store.compare_models("gpt-4", "claude-3")
    #
    # @see TestRun
    # @see TestResult
    class ResultStore
      include Persistence
      include Querying
      include Analysis

      # Creates a new result store.
      #
      # @param path [String, Pathname] Directory path for storing results
      def initialize(path: "test_results")
        initialize_persistence(path)
      end

      # Stores a test run with metadata.
      #
      # @param run [TestRun] The test run to store
      # @param model_id [String] Model identifier
      # @param timestamp [Time] When the test was run (default: now)
      # @return [Hash] The stored data
      def store(run:, model_id:, timestamp: Time.now)
        data = build_result_data(run, model_id, timestamp)
        write_result(model_id, run.test_case.name, data)
        data
      end

      private

      def build_result_data(run, model_id, timestamp)
        {
          model_id:,
          timestamp: timestamp.iso8601,
          test_case: run.test_case.to_h,
          summary: run.summary,
          results: run.results.map(&:to_h)
        }
      end
    end
  end
end
