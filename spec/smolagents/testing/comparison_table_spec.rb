RSpec.describe Smolagents::Testing::ComparisonTable do
  describe ".format" do
    it "returns a formatted comparison table" do
      summary1 = instance_double(
        Smolagents::Testing::BenchmarkSummary,
        max_level_passed: 5,
        avg_tokens_per_second: 50,
        pass_rate: 0.8,
        total_duration: 10.0,
        level_badge: "REASONING",
        capabilities: double(architecture: "transformer")
      )

      summary2 = instance_double(
        Smolagents::Testing::BenchmarkSummary,
        max_level_passed: 3,
        avg_tokens_per_second: 100,
        pass_rate: 0.6,
        total_duration: 5.0,
        level_badge: "TOOL_CAPABLE",
        capabilities: double(architecture: "mamba")
      )

      summaries = { "model-1" => summary1, "model-2" => summary2 }
      result = described_class.format(summaries)

      expect(result).to include("MODEL COMPATIBILITY MATRIX")
      expect(result).to include("model-1")
      expect(result).to include("model-2")
      expect(result).to include("REASONING")
      expect(result).to include("TOOL_CAPABLE")
      expect(result).to include("Legend:")
    end

    it "sorts summaries by max_level_passed then by tokens_per_second" do
      summary_low = instance_double(
        Smolagents::Testing::BenchmarkSummary,
        max_level_passed: 1,
        avg_tokens_per_second: 100,
        pass_rate: 0.5,
        total_duration: 5.0,
        level_badge: "BASIC",
        capabilities: double(architecture: "?")
      )

      summary_high = instance_double(
        Smolagents::Testing::BenchmarkSummary,
        max_level_passed: 5,
        avg_tokens_per_second: 50,
        pass_rate: 0.8,
        total_duration: 10.0,
        level_badge: "REASONING",
        capabilities: double(architecture: "transformer")
      )

      summaries = { "low" => summary_low, "high" => summary_high }
      result = described_class.format(summaries)

      # Higher level should appear before lower level
      high_idx = result.index("high")
      low_idx = result.index("low")
      expect(high_idx).to be < low_idx
    end
  end

  describe ".header" do
    it "contains column headers and separators" do
      header = described_class.header

      expect(header).to include("=" * 100)
      expect(header).to include("MODEL COMPATIBILITY MATRIX")
      expect(header).to include("Model")
      expect(header).to include("Params")
      expect(header).to include("Level")
      expect(header).to include("Pass")
      expect(header).to include("Time")
      expect(header).to include("Tok/s")
    end
  end

  describe ".footer" do
    it "contains the legend" do
      footer = described_class.footer

      expect(footer).to include("Legend:")
      expect(footer).to include("INCOMPATIBLE")
      expect(footer).to include("BASIC")
      expect(footer).to include("FORMAT_OK")
      expect(footer).to include("TOOL_CAPABLE")
      expect(footer).to include("MULTI_STEP")
      expect(footer).to include("REASONING")
    end
  end

  describe ".header_columns" do
    it "returns array with correct column names" do
      columns = described_class.header_columns

      expect(columns).to be_an(Array)
      expect(columns.size).to eq(7)
      expect(columns[0]).to include("Model")
      expect(columns[1]).to include("Params")
      expect(columns[2]).to include("Level")
      expect(columns[3]).to include("Pass")
      expect(columns[4]).to include("Time")
      expect(columns[5]).to include("Tok/s")
      expect(columns[6]).to include("Arch")
    end
  end

  describe ".row" do
    it "formats a summary as a table row" do
      summary = instance_double(
        Smolagents::Testing::BenchmarkSummary,
        max_level_passed: 4,
        avg_tokens_per_second: 75,
        pass_rate: 0.75,
        total_duration: 8.0,
        level_badge: "MULTI_STEP",
        capabilities: double(architecture: "transformer")
      )

      row = described_class.row("test-model", summary)

      expect(row).to include("test-model")
      expect(row).to include("MULTI_STEP")
      expect(row).to include("75%")
      expect(row).to include("8.0s")
      expect(row).to include("75")
      expect(row).to include("transformer")
    end

    it "handles nil capabilities gracefully" do
      summary = instance_double(
        Smolagents::Testing::BenchmarkSummary,
        max_level_passed: 2,
        avg_tokens_per_second: 50,
        pass_rate: 0.5,
        total_duration: 10.0,
        level_badge: "FORMAT_OK",
        capabilities: nil
      )

      row = described_class.row("unknown-model", summary)

      expect(row).to include("unknown-model")
      expect(row).to include("?")
    end
  end

  describe ".row_values" do
    it "returns array with model column, summary columns, and architecture" do
      summary = instance_double(
        Smolagents::Testing::BenchmarkSummary,
        max_level_passed: 3,
        avg_tokens_per_second: 60,
        pass_rate: 0.7,
        total_duration: 7.0,
        level_badge: "TOOL_CAPABLE",
        capabilities: double(architecture: "transformer")
      )

      values = described_class.row_values("test-model", summary)

      expect(values).to be_an(Array)
      expect(values.first).to include("test-model")
      expect(values.last).to eq("transformer")
    end
  end

  describe "column widths" do
    it "defines consistent column widths" do
      widths = described_class::COL_WIDTHS

      expect(widths).to have_key(:model)
      expect(widths).to have_key(:params)
      expect(widths).to have_key(:level)
      expect(widths).to have_key(:pass)
      expect(widths).to have_key(:time)
      expect(widths).to have_key(:toks)

      expect(widths.values).to all(be_a(Integer))
    end
  end

  describe "legend constant" do
    it "contains all capability levels" do
      legend = described_class::LEGEND

      expect(legend).to be_an(Array)
      expect(legend).to all(be_a(String))
      expect(legend.join).to include("INCOMPATIBLE")
      expect(legend.join).to include("BASIC")
      expect(legend.join).to include("REASONING")
    end
  end

  describe ".level_col" do
    it "formats level column with badge" do
      summary = double(level_badge: "REASONING")
      col = described_class.level_col(summary)

      expect(col).to include("REASONING")
      expect(col).to be_a(String)
    end
  end

  describe ".pass_col" do
    it "formats pass rate as percentage" do
      summary = double(pass_rate: 0.85)
      col = described_class.pass_col(summary)

      expect(col).to include("85%")
    end

    it "right-aligns the percentage" do
      summary = double(pass_rate: 0.5)
      col = described_class.pass_col(summary)

      expect(col).to end_with("50%")
    end
  end

  describe ".time_col" do
    it "formats duration in seconds" do
      summary = double(total_duration: 12.5)
      col = described_class.time_col(summary)

      expect(col).to include("12.5s")
    end
  end

  describe ".toks_col" do
    it "formats tokens per second" do
      summary = double(avg_tokens_per_second: 123.456)
      col = described_class.toks_col(summary)

      expect(col).to include("123")
    end

    it "rounds to integer" do
      summary = double(avg_tokens_per_second: 50.6)
      col = described_class.toks_col(summary)

      expect(col).to include("51")
    end
  end
end
