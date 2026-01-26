module Smolagents
  module Testing
    class ModelBenchmark
      # Result aggregation logic for multi-run benchmarks.
      #
      # Combines results from multiple test runs to produce
      # statistically meaningful pass/fail determinations.
      module Aggregator
        # Run a test multiple times and aggregate results.
        #
        # @param model_id [String] Model to test
        # @param test [Hash] Test definition
        # @param timeout [Integer] Timeout per run
        # @param runs [Integer] Number of runs
        # @param pass_threshold [Float] Fraction of runs required to pass
        # @return [BenchmarkResult] Aggregated result
        def run_test_with_retries(model_id, test, timeout:, runs:, pass_threshold:)
          return run_test(model_id, test, timeout:) if runs == 1

          attempts = collect_attempts(model_id, test, timeout, runs)
          aggregate_results(model_id, test, attempts, pass_threshold)
        end

        private

        def collect_attempts(model_id, test, timeout, runs)
          Array.new(runs) do |i|
            @logger.debug("  Run #{i + 1}/#{runs} for #{test[:name]}...")
            run_test(model_id, test, timeout:)
          end
        end

        def aggregate_results(model_id, test, attempts, pass_threshold)
          stats = compute_attempt_stats(attempts, pass_threshold)
          build_aggregate_result(model_id, test, stats)
        end

        def compute_attempt_stats(attempts, pass_threshold)
          pass_info = compute_pass_info(attempts, pass_threshold)
          build_stats_hash(attempts, pass_info)
        end

        def compute_pass_info(attempts, pass_threshold)
          passed_count = attempts.count(&:passed?)
          pass_rate = passed_count.to_f / attempts.size
          { passed_count:, pass_rate:, passed: pass_rate >= pass_threshold }
        end

        def build_stats_hash(attempts, pass_info)
          {
            **pass_info,
            representative: select_representative(attempts, pass_info[:passed]),
            tokens: sum_tokens(attempts),
            avg_duration: attempts.sum(&:duration) / attempts.size,
            metadata: build_attempt_metadata(attempts, pass_info[:passed_count], pass_info[:pass_rate]),
            errors: collect_errors(attempts)
          }
        end

        def sum_tokens(attempts)
          attempts.filter_map(&:tokens).sum(TokenUsage.zero)
        end

        def select_representative(attempts, passed)
          passed ? attempts.select(&:passed?).min_by(&:duration) : attempts.max_by(&:duration)
        end

        def build_attempt_metadata(attempts, passed_count, pass_rate)
          { runs: attempts.size, passed_runs: passed_count, pass_rate: pass_rate.round(3),
            durations: attempts.map { it.duration.round(3) } }
        end

        def collect_errors(attempts)
          attempts.reject(&:passed?).map(&:error).uniq.join("; ")
        end

        def build_aggregate_result(model_id, test, stats)
          common = {
            model_id:, test_name: test[:name], level: test[:level],
            duration: stats[:avg_duration], tokens: stats[:tokens],
            steps: stats[:representative].steps, metadata: stats[:metadata]
          }
          return BenchmarkResult.success(**common) if stats[:passed]

          error = "#{stats[:passed_count]}/#{stats[:metadata][:runs]} passed: #{stats[:errors]}"
          BenchmarkResult.failure(**common, error:)
        end
      end
    end
  end
end
