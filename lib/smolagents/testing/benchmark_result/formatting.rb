module Smolagents
  module Testing
    # Report formatting methods for BenchmarkSummary.
    #
    # Extracted to keep formatting concerns separate from aggregation logic.
    module SummaryFormatting
      # Generate a comprehensive human-readable report.
      #
      # @return [String] Formatted multi-line report
      def report = [report_header, report_metrics, report_table].join("\n")

      # Get model capability flags as a comma-separated string.
      #
      # @return [String] Comma-separated capability flags
      def capability_flags
        flags = []
        flags << "tool_use" if capabilities&.tool_use?
        flags << "vision" if capabilities&.vision?
        flags << "#{capabilities.reasoning}_reasoning" if capabilities
        flags.join(", ")
      end

      # Convert summary to a hash representation.
      #
      # @return [Hash] Hash with all metrics and results
      def to_h
        {
          model_id:, capabilities: capabilities&.to_h, max_level_passed:, level_badge:,
          total_duration:, total_tokens: total_tokens.to_h, pass_rate:, avg_tokens_per_second:,
          results: results.map { |r| result_to_h(r) }
        }
      end

      private

      def report_header
        lines = [separator("="), "Model: #{model_id}"]
        if capabilities
          c = capabilities
          lines << "Architecture: #{c.architecture} | Params: #{c.param_count_str} | Context: #{c.context_length}"
        end
        lines << "Capabilities: #{capability_flags}" if capabilities
        lines.join("\n")
      end

      def report_metrics
        [
          separator("-"),
          "Rating: #{level_badge} (Level #{max_level_passed})",
          format_pass_rate,
          format_throughput,
          format_total_tokens
        ].compact.join("\n")
      end

      def format_pass_rate
        "Pass Rate: #{(pass_rate * 100).round(1)}% (#{results.count(&:passed?)}/#{results.size})"
      end

      def format_throughput
        "Total Time: #{total_duration.round(2)}s | Avg Throughput: #{avg_tokens_per_second.round(0)} tok/s"
      end

      def format_total_tokens
        "Total Tokens: #{total_tokens.total_tokens}" if total_tokens.total_tokens.positive?
      end

      def report_table
        [separator("-"), table_header, separator("-"), *results.map(&:to_row), separator("=")].join("\n")
      end

      def table_header = "#{"TEST".ljust(30)}| #{"TIME".rjust(8)} | #{"THROUGHPUT".rjust(12)}"

      def separator(char) = char * 70

      def result_to_h(result)
        { test_name: result.test_name, level: result.level, passed: result.passed, duration: result.duration }
      end
    end
  end
end
