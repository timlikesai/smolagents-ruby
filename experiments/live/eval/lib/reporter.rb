# Reporter
#
# Generates comparison reports from stored results.
# Creates markdown reports showing model performance across suites.

require "fileutils"

module LiveExperiments
  module Eval
    class Reporter
      REPORTS_DIR = File.expand_path("../reports", __dir__)

      def initialize(store:)
        @store = store
      end

      # Generate comparison report for all models across all suites
      def generate_comparison
        suites = @store.suites_with_results
        return "No results found." if suites.empty?

        lines = [
          "# Model Evaluation Report",
          "",
          "Generated: #{Time.now.strftime("%Y-%m-%d %H:%M")}",
          "",
          "## Summary Matrix",
          ""
        ]

        lines.concat(generate_matrix(suites))
        lines.concat(generate_detailed_sections(suites))

        report = lines.join("\n")
        save_report(report)
        report
      end

      # Generate report for a specific model
      def generate_model_report(model_id)
        suites = @store.suites_with_results.select { |s| @store.has_results?(model_id, s) }
        return "No results for model: #{model_id}" if suites.empty?

        lines = [
          "# Model Report: #{model_id}",
          "",
          "Generated: #{Time.now.strftime("%Y-%m-%d %H:%M")}",
          ""
        ]

        suites.each do |suite_name|
          result = @store.latest(model_id, suite_name)
          next unless result

          lines.concat(format_suite_result(result))
        end

        lines.join("\n")
      end

      private

      def generate_matrix(suites)
        # Collect all models
        all_models = suites.flat_map { |s| @store.models_for_suite(s) }.uniq.sort

        # Header row
        lines = ["| Model | #{suites.join(" | ")} |"]
        lines << "|#{"-" * 6}|#{suites.map { "-" * 6 }.join("|")}|"

        # Data rows
        all_models.each do |model_id|
          cells = suites.map do |suite_name|
            result = @store.latest(model_id, suite_name)
            result ? format_pass_rate(result.summary.pass_rate) : "-"
          end
          lines << "| #{truncate_model(model_id)} | #{cells.join(" | ")} |"
        end

        lines << ""
        lines
      end

      def generate_detailed_sections(suites)
        lines = ["## Detailed Results", ""]

        suites.each do |suite_name|
          lines << "### #{suite_name}"
          lines << ""

          models = @store.models_for_suite(suite_name)
          models.each do |model_id|
            result = @store.latest(model_id, suite_name)
            next unless result

            lines << "**#{model_id}**: #{result.summary.passed}/#{result.summary.total} " \
                     "(#{format_pass_rate(result.summary.pass_rate)}) " \
                     "avg: #{result.summary.avg_duration_ms}ms"

            # List failed tests
            failed = result.test_results.reject(&:passed)
            if failed.any?
              lines << "  - Failed: #{failed.map(&:test_name).join(", ")}"
            end

            lines << ""
          end
        end

        lines
      end

      def format_suite_result(result)
        lines = [
          "## #{result.suite_name}",
          "",
          "- **Pass Rate**: #{format_pass_rate(result.summary.pass_rate)}",
          "- **Passed**: #{result.summary.passed}/#{result.summary.total}",
          "- **Avg Duration**: #{result.summary.avg_duration_ms}ms",
          "- **Tested**: #{result.timestamp.strftime("%Y-%m-%d %H:%M")}",
          ""
        ]

        # Test details
        lines << "### Test Results"
        lines << ""
        result.test_results.each do |tr|
          status = tr.passed ? "PASS" : "FAIL"
          lines << "- [#{status}] #{tr.test_name} (#{tr.duration_ms}ms)"
          lines << "  - Error: #{tr.error}" if tr.error
        end

        lines << ""
        lines
      end

      def format_pass_rate(rate)
        "#{(rate * 100).round}%"
      end

      def truncate_model(model_id)
        model_id.length > 25 ? "#{model_id[0..22]}..." : model_id
      end

      def save_report(content)
        FileUtils.mkdir_p(REPORTS_DIR)
        path = File.join(REPORTS_DIR, "comparison_#{Time.now.strftime("%Y%m%d_%H%M")}.md")
        File.write(path, content)
        path
      end
    end
  end
end
