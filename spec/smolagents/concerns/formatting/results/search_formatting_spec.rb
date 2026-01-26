require "spec_helper"

RSpec.describe Smolagents::Concerns::Results::SearchFormatting do
  subject(:formatter) { test_class.new }

  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::Results::SearchFormatting
    end
  end

  describe "#format_search_results" do
    let(:empty_message) { "No results found." }
    let(:item_formatter) do
      ->(r) { "## #{r[:title]}\n#{r[:link]}\n#{r[:snippet]}" }
    end

    context "with standard search results" do
      let(:results) do
        [
          { title: "Ruby Programming Language", link: "https://ruby-lang.org", snippet: "Language info" },
          { title: "Ruby on Rails", link: "https://rubyonrails.org", snippet: "Web framework" }
        ]
      end

      it "formats results using item_formatter" do
        output = formatter.format_search_results(
          results,
          empty_message:,
          item_formatter:
        )

        expect(output).to include("Ruby Programming Language")
        expect(output).to include("https://ruby-lang.org")
        expect(output).to include("Language info")
      end

      it "includes result count" do
        output = formatter.format_search_results(
          results,
          empty_message:,
          item_formatter:
        )

        expect(output).to include("Found 2 results")
      end

      it "separates results with dividers" do
        output = formatter.format_search_results(
          results,
          empty_message:,
          item_formatter:
        )

        expect(output).to include("---")
      end
    end

    context "with empty results" do
      it "returns empty message" do
        output = formatter.format_search_results(
          [],
          empty_message:,
          item_formatter:
        )

        expect(output).to eq(empty_message)
      end
    end

    context "with next_steps" do
      let(:results) { [{ title: "Test", link: "http://test.com", snippet: "Info" }] }
      let(:next_steps) { "Try different search terms." }

      it "appends next steps to output" do
        output = formatter.format_search_results(
          results,
          empty_message:,
          item_formatter:,
          next_steps:
        )

        expect(output).to include(next_steps)
      end
    end

    context "with max_results" do
      let(:results) { (1..10).map { |i| { title: "Result #{i}", link: "http://#{i}.com", snippet: "Info #{i}" } } }

      it "limits results when max_results provided" do
        output = formatter.format_search_results(
          results,
          empty_message:,
          item_formatter:,
          max_results: 3
        )

        expect(output).to include("Found 3 result")
        expect(output).to include("Result 1")
        expect(output).to include("Result 2")
        expect(output).to include("Result 3")
        expect(output).not_to include("Result 4")
      end

      it "respects @max_results instance variable" do
        formatter.instance_variable_set(:@max_results, 2)

        output = formatter.format_search_results(
          results,
          empty_message:,
          item_formatter:
        )

        expect(output).to include("Found 2 results")
      end
    end

    context "with custom item formatter" do
      let(:results) { [{ name: "Custom Item", url: "http://custom.com" }] }

      it "uses provided item_formatter" do
        custom_formatter = ->(r) { "[#{r[:name]}](#{r[:url]})" }

        output = formatter.format_search_results(
          results,
          empty_message:,
          item_formatter: custom_formatter
        )

        expect(output).to include("[Custom Item](http://custom.com)")
      end
    end

    context "with single result" do
      let(:results) { [{ title: "Only Result", link: "http://only.com", snippet: "Solo" }] }

      it "uses singular 'result' word" do
        output = formatter.format_search_results(
          results,
          empty_message:,
          item_formatter:
        )

        expect(output).to include("Found 1 result")
        expect(output).not_to include("results")
      end
    end
  end

  describe "private methods" do
    describe "#build_search_output" do
      it "builds output without next steps" do
        result = formatter.send(:build_search_output, 2, "formatted content", nil)

        expect(result).to include("Found 2 results")
        expect(result).to include("formatted content")
      end

      it "builds output with next steps" do
        result = formatter.send(:build_search_output, 1, "content", "Try again")

        expect(result).to include("Found 1 result")
        expect(result).to include("content")
        expect(result).to include("Try again")
      end

      it "uses singular for single result" do
        result = formatter.send(:build_search_output, 1, "content", nil)

        expect(result).to include("Found 1 result")
        expect(result).not_to match(/1 results/)
      end
    end
  end
end
