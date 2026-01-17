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
      # Creates a new result store.
      #
      # @param path [String, Pathname] Directory path for storing results
      def initialize(path: "test_results")
        @path = Pathname.new(path)
        @path.mkpath unless @path.exist?
      end

      # Stores a test run with metadata.
      #
      # @param run [TestRun] The test run to store
      # @param model_id [String] Model identifier
      # @param timestamp [Time] When the test was run (default: now)
      # @return [Hash] The stored data
      def store(run:, model_id:, timestamp: Time.now)
        data = {
          model_id:,
          timestamp: timestamp.iso8601,
          test_case: run.test_case.to_h,
          summary: run.summary,
          results: run.results.map(&:to_h)
        }
        write_result(model_id, run.test_case.name, data)
        data
      end

      # Finds all results for a specific model.
      #
      # @param model_id [String] Model identifier
      # @return [Array<Hash>] Results matching the model
      def find_by_model(model_id)
        load_results.select { |r| r[:model_id] == model_id }
      end

      # Finds all results testing a specific capability.
      #
      # @param capability [String, Symbol] Capability name
      # @return [Array<Hash>] Results matching the capability
      def find_by_capability(capability)
        load_results.select { |r| r.dig(:test_case, :capability) == capability.to_s }
      end

      # Finds all results for a specific test.
      #
      # @param test_name [String, Symbol] Test case name
      # @return [Array<Hash>] Results matching the test name
      def find_by_test(test_name)
        load_results.select { |r| r.dig(:test_case, :name) == test_name.to_s }
      end

      # Returns all stored results.
      #
      # @return [Array<Hash>] All results
      def all_results = load_results

      # Compares results across multiple models.
      #
      # @param model_ids [Array<String>] Model identifiers to compare
      # @return [Hash{String => Array<Hash>}] Results grouped by model
      def compare_models(*model_ids)
        model_ids.flatten.to_h { |id| [id, find_by_model(id)] }
      end

      # Detect regression for a model/test combination.
      #
      # Returns true if the most recent pass_rate dropped by more than
      # threshold compared to the previous run.
      #
      # @param model_id [String] Model identifier
      # @param test_name [String] Test name
      # @param threshold [Float] Minimum drop to consider regression (default: 0.1)
      # @return [Boolean] True if regression detected
      def regression?(model_id, test_name, threshold: 0.1)
        history = find_by_model(model_id)
                  .select { |r| r.dig(:test_case, :name) == test_name.to_s }
                  .sort_by { |r| r[:timestamp] }

        return false if history.size < 2

        recent = history.last.dig(:summary, :pass_rate)
        previous = history[-2].dig(:summary, :pass_rate)
        (previous - recent) > threshold
      end

      # Detect improvement for a model/test combination.
      #
      # Returns true if the most recent pass_rate improved by more than
      # threshold compared to the previous run.
      #
      # @param model_id [String] Model identifier
      # @param test_name [String] Test name
      # @param threshold [Float] Minimum improvement to consider (default: 0.1)
      # @return [Boolean] True if improvement detected
      def improvement?(model_id, test_name, threshold: 0.1)
        history = find_by_model(model_id)
                  .select { |r| r.dig(:test_case, :name) == test_name.to_s }
                  .sort_by { |r| r[:timestamp] }

        return false if history.size < 2

        recent = history.last.dig(:summary, :pass_rate)
        previous = history[-2].dig(:summary, :pass_rate)
        (recent - previous) > threshold
      end

      # Compute the trend for a model/test combination.
      #
      # Analyzes the average change in pass_rate over a window of recent runs
      # to determine if performance is improving, degrading, or stable.
      #
      # @param model_id [String] Model identifier
      # @param test_name [String] Test name
      # @param window [Integer] Number of recent results to analyze (default: 5)
      # @return [Symbol] :improving, :degrading, :stable, or :insufficient_data
      def trend(model_id, test_name, window: 5)
        history = fetch_history(model_id, test_name, window)
        return :insufficient_data if history.size < 2

        classify_trend(calculate_avg_change(history))
      end

      def fetch_history(model_id, test_name, window)
        find_by_model(model_id)
          .select { |r| r.dig(:test_case, :name) == test_name.to_s }
          .sort_by { |r| r[:timestamp] }.last(window)
      end

      def calculate_avg_change(history)
        rates = history.map { |r| r.dig(:summary, :pass_rate) }
        rates.each_cons(2).sum { |a, b| b - a } / (rates.size - 1)
      end

      def classify_trend(avg)
        if avg > 0.05
          :improving
        else
          (avg < -0.05 ? :degrading : :stable)
        end
      end

      private

      def write_result(model_id, test_name, data)
        dir = @path / sanitize(model_id)
        dir.mkpath
        file = dir / "#{sanitize(test_name)}_#{data[:timestamp].tr(":", "-")}.json"
        file.write(JSON.pretty_generate(data))
      end

      def load_results
        @path.glob("**/*.json").filter_map do |file|
          JSON.parse(file.read, symbolize_names: true)
        rescue JSON::ParserError
          nil
        end
      end

      def sanitize(name) = name.to_s.gsub(/[^a-zA-Z0-9_-]/, "_")
    end
  end
end
