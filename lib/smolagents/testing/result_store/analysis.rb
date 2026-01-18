module Smolagents
  module Testing
    class ResultStore
      # Trend analysis for test results over time.
      #
      # Provides methods to detect regressions, improvements, and overall trends
      # in model performance based on historical test runs.
      module Analysis
        IMPROVEMENT_THRESHOLD = 0.05
        private_constant :IMPROVEMENT_THRESHOLD

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
          detect_change(model_id, test_name, threshold:, direction: :negative)
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
          detect_change(model_id, test_name, threshold:, direction: :positive)
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

        private

        # rubocop:disable Naming/PredicateMethod -- returns result, not predicate
        def detect_change(model_id, test_name, threshold:, direction:)
          history = fetch_history(model_id, test_name, 2)
          return false if history.size < 2

          recent = history.last.dig(:summary, :pass_rate)
          previous = history.first.dig(:summary, :pass_rate)
          delta = recent - previous

          direction == :positive ? delta > threshold : delta < -threshold
        end
        # rubocop:enable Naming/PredicateMethod

        def calculate_avg_change(history)
          rates = history.map { |r| r.dig(:summary, :pass_rate) }
          rates.each_cons(2).sum { |a, b| b - a } / (rates.size - 1)
        end

        def classify_trend(avg)
          if avg > IMPROVEMENT_THRESHOLD
            :improving
          elsif avg < -IMPROVEMENT_THRESHOLD
            :degrading
          else
            :stable
          end
        end
      end
    end
  end
end
