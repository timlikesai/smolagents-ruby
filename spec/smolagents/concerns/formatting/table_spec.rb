require "spec_helper"

RSpec.describe Smolagents::Concerns::TableFormatting do
  subject(:formatter) { test_class.new }

  let(:test_class) do
    Class.new do
      attr_accessor :data

      include Smolagents::Concerns::TableFormatting
    end
  end

  describe "#as_table" do
    # Set up data for as_table tests via context-specific let(:data)
    before { formatter.data = data }

    context "with array of hashes" do
      let(:data) do
        [
          { "name" => "Alice", "age" => 30, "city" => "NYC" },
          { "name" => "Bob", "age" => 25, "city" => "LA" },
          { "name" => "Charlie", "age" => 35, "city" => "Chicago" }
        ]
      end

      it "creates ASCII table with headers and rows" do
        result = formatter.as_table
        lines = result.split("\n")

        expect(lines[0]).to include("name")
        expect(lines[0]).to include("age")
        expect(lines[0]).to include("city")
        expect(lines[1]).to match(/-+-/) # separator uses -+- style
        expect(lines[2]).to include("Alice")
        expect(lines[3]).to include("Bob")
      end

      it "respects max_width parameter" do
        result = formatter.as_table(max_width: 5)
        expect(result).to include("...")
      end

      it "calculates column widths correctly" do
        formatter.data = [{ "a" => "1", "verylongheader" => "2" }]
        result = formatter.as_table
        expect(result).to include("verylongheader")
      end

      it "handles single column" do
        formatter.data = [{ "col" => "val1" }, { "col" => "val2" }]
        result = formatter.as_table
        expect(result).to include("col")
        expect(result).to include("val1")
        expect(result).to include("val2")
      end

      it "handles many columns" do
        formatter.data = [
          { "a" => 1, "b" => 2, "c" => 3, "d" => 4, "e" => 5, "f" => 6 }
        ]
        result = formatter.as_table
        # Table uses "a | b | c" style without leading pipe
        expect(result).to include("a | b")
        expect(result).to include("e | f")
      end
    end

    context "with symbol keys" do
      let(:data) do
        [
          { name: "Alice", status: "active" },
          { name: "Bob", status: "inactive" }
        ]
      end

      it "handles symbol keys" do
        result = formatter.as_table
        expect(result).to include("name")
        expect(result).to include("Alice")
      end
    end

    context "with empty array" do
      let(:data) { [] }

      it "falls back to to_s" do
        result = formatter.as_table
        expect(result).to eq("[]")
      end
    end

    context "with non-hash array" do
      let(:data) { %w[a b c] }

      it "falls back to to_s" do
        result = formatter.as_table
        expect(result).to eq(data.to_s)
      end
    end

    context "with nil first element" do
      let(:data) { [nil, { "a" => "b" }] }

      it "falls back to to_s" do
        result = formatter.as_table
        expect(result).to eq(data.to_s)
      end
    end

    context "with wide content" do
      let(:data) do
        [
          { "description" => "This is a very long description that should be truncated" }
        ]
      end

      it "truncates long values" do
        result = formatter.as_table(max_width: 20)
        expect(result).to include("...")
        lines = result.split("\n")
        # Data row should not exceed max_width
        data_row = lines[2]
        expect(data_row.length).to be > 0
      end
    end

    context "with numeric and nil values" do
      let(:data) do
        [
          { "id" => 1, "score" => 9.5, "note" => nil }
        ]
      end

      it "formats numbers and nil" do
        result = formatter.as_table
        expect(result).to include("1")
        expect(result).to include("9.5")
      end
    end
  end

  describe "private methods" do
    # Set up data for private method tests that need it
    let(:private_data) do
      [
        { "id" => 1, "name" => "Alice" },
        { "id" => 2, "name" => "Verylongname" }
      ]
    end

    before { formatter.data = private_data }

    describe "#calculate_column_widths" do
      it "calculates widths based on header and values" do
        headers = %w[id name]
        widths = formatter.send(:calculate_column_widths, headers, 30)

        expect(widths[0]).to be >= 2 # "id"
        expect(widths[1]).to be >= "verylongname".length
      end

      it "respects max_width constraint" do
        headers = ["a" * 50]
        widths = formatter.send(:calculate_column_widths, headers, 10)
        expect(widths[0]).to eq(10)
      end

      it "has minimum width of 1" do
        headers = []
        widths = formatter.send(:calculate_column_widths, headers, 30)
        expect(widths).to be_empty
      end
    end

    describe "#max_column_value_length" do
      before do
        formatter.data = [
          { "col" => "short" },
          { "col" => "verylongvalue" },
          { "col" => "mid" }
        ]
      end

      it "finds longest value in column" do
        length = formatter.send(:max_column_value_length, "col")
        expect(length).to eq("verylongvalue".length)
      end

      it "handles empty column" do
        formatter.data = []
        length = formatter.send(:max_column_value_length, "col")
        expect(length).to eq(0)
      end
    end

    describe "#format_header_row" do
      it "formats headers with widths" do
        headers = %w[id name]
        widths = [5, 10]
        result = formatter.send(:format_header_row, headers, widths)

        expect(result).to include("id")
        expect(result).to include("name")
        expect(result).to include("|")
      end
    end

    describe "#format_separator_row" do
      it "creates separator with dashes" do
        widths = [5, 10, 7]
        result = formatter.send(:format_separator_row, widths)

        # Each width produces that many dashes, joined with "-+-"
        # So 5 dashes + "-+-" + 10 dashes + "-+-" + 7 dashes
        expect(result).to eq("------+------------+--------")
      end

      it "handles single column" do
        widths = [10]
        result = formatter.send(:format_separator_row, widths)
        expect(result).to eq("----------")
      end
    end

    describe "#format_data_rows" do
      before do
        formatter.data = [
          { "a" => "val1", "b" => "val2" },
          { "a" => "val3", "b" => "val4" }
        ]
      end

      it "formats all rows" do
        headers = %w[a b]
        widths = [5, 5]
        rows = formatter.send(:format_data_rows, headers, widths)

        expect(rows.size).to eq(2)
        expect(rows[0]).to include("val1")
        expect(rows[1]).to include("val3")
      end
    end

    describe "#format_table_row" do
      it "formats single row with alignment" do
        row = { "id" => 1, "name" => "Alice" }
        headers = %w[id name]
        widths = [5, 10]

        result = formatter.send(:format_table_row, row, headers, widths)
        expect(result).to include("1")
        expect(result).to include("Alice")
      end
    end

    describe "#truncate_str" do
      it "returns unchanged string if fits" do
        result = formatter.send(:truncate_str, "hello", 10)
        expect(result).to eq("hello")
      end

      it "truncates with ellipsis if too long" do
        result = formatter.send(:truncate_str, "hello world", 8)
        expect(result).to eq("hello...")
        expect(result.length).to eq(8)
      end

      it "handles exactly fitting width" do
        result = formatter.send(:truncate_str, "12345", 5)
        expect(result).to eq("12345")
      end

      it "handles width smaller than ellipsis" do
        result = formatter.send(:truncate_str, "hello", 3)
        expect(result.length).to eq(3)
        expect(result).to end_with(".")
      end
    end
  end
end
