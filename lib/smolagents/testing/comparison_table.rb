module Smolagents
  module Testing
    # Formats benchmark summaries into a comparison table.
    #
    # Provides formatted output for comparing multiple models side-by-side.
    module ComparisonTable
      COL_WIDTHS = { model: 26, params: 6, level: 12, pass: 6, time: 8, toks: 8 }.freeze

      LEGEND = [
        "Legend: Level indicates highest test tier passed",
        "  INCOMPATIBLE - Cannot respond coherently",
        "  BASIC        - Can respond, but not in correct format",
        "  FORMAT_OK    - Generates proper Ruby code blocks",
        "  TOOL_CAPABLE - Can call tools correctly",
        "  MULTI_STEP   - Can complete multi-step tasks",
        "  REASONING    - Can handle complex reasoning"
      ].freeze

      module_function

      # Format summaries into a comparison table.
      #
      # @param summaries [Hash{String => BenchmarkSummary}]
      # @return [String] Formatted comparison table
      def format(summaries)
        sorted = summaries.sort_by { |_, s| [-s.max_level_passed, -s.avg_tokens_per_second] }
        [header, *sorted.map { |id, s| row(id, s) }, footer].join("\n")
      end

      def header
        ["=" * 100, "MODEL COMPATIBILITY MATRIX", "=" * 100, header_columns.join(" | "), "-" * 100].join("\n")
      end

      def header_columns
        w = COL_WIDTHS
        [
          "Model".ljust(w[:model]), "Params".rjust(w[:params]), "Level".ljust(w[:level]),
          "Pass".rjust(w[:pass]), "Time".rjust(w[:time]), "Tok/s".rjust(w[:toks]), "Arch"
        ]
      end

      def row(id, summary) = row_values(id, summary).join(" | ")

      def row_values(id, summary)
        [model_col(id, summary), summary_cols(summary), summary.capabilities&.architecture || "?"].flatten
      end

      def model_col(id, summary)
        w = COL_WIDTHS
        caps = summary.capabilities
        [id.ljust(w[:model]), (caps&.size_str || "?").rjust(w[:params])]
      end

      def summary_cols(summary)
        [level_col(summary), pass_col(summary), time_col(summary), toks_col(summary)]
      end

      def level_col(summary) = summary.level_badge.ljust(COL_WIDTHS[:level])
      def pass_col(summary) = Kernel.format("%d%%", summary.pass_rate * 100).rjust(COL_WIDTHS[:pass])
      def time_col(summary) = Kernel.format("%.1fs", summary.total_duration).rjust(COL_WIDTHS[:time])
      def toks_col(summary) = summary.avg_tokens_per_second.round(0).to_s.rjust(COL_WIDTHS[:toks])

      def footer = (["=" * 100, ""] + LEGEND).join("\n")
    end
  end
end
