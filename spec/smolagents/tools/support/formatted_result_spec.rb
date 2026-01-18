require "spec_helper"

RSpec.describe Smolagents::Tools::Support::FormattedResult do
  let(:test_class) do
    Class.new do
      include Smolagents::Tools::Support::FormattedResult

      attr_accessor :max_results

      def initialize(max_results: 3)
        @max_results = max_results
      end
    end
  end

  let(:instance) { test_class.new }

  describe "#format_search_results" do
    let(:results) do
      [
        { title: "Result 1", body: "Body 1" },
        { title: "Result 2", body: "Body 2" },
        { title: "Result 3", body: "Body 3" }
      ]
    end

    let(:item_formatter) { ->(r) { "## #{r[:title]}\n#{r[:body]}" } }

    it "returns empty message when results are empty" do
      output = instance.format_search_results(
        [],
        empty_message: "No results found.",
        item_formatter:
      )

      expect(output).to eq("No results found.")
    end

    it "formats results with count header" do
      output = instance.format_search_results(
        results,
        empty_message: "No results.",
        item_formatter:
      )

      expect(output).to include("Found 3 results")
      expect(output).to include("## Result 1")
      expect(output).to include("## Result 2")
      expect(output).to include("## Result 3")
    end

    it "separates results with dividers" do
      output = instance.format_search_results(
        results,
        empty_message: "No results.",
        item_formatter:
      )

      expect(output).to include("---")
    end

    it "appends next steps when provided" do
      output = instance.format_search_results(
        results,
        empty_message: "No results.",
        item_formatter:,
        next_steps: "Try a different query."
      )

      expect(output).to include("Try a different query.")
    end

    it "respects max_results limit" do
      instance.max_results = 2
      output = instance.format_search_results(
        results,
        empty_message: "No results.",
        item_formatter:
      )

      expect(output).to include("Found 2 results")
      expect(output).to include("## Result 1")
      expect(output).to include("## Result 2")
      expect(output).not_to include("## Result 3")
    end

    it "uses singular when count is 1" do
      output = instance.format_search_results(
        [results.first],
        empty_message: "No results.",
        item_formatter:
      )

      expect(output).to include("Found 1 result")
      expect(output).not_to include("results")
    end

    it "accepts explicit max_results parameter" do
      output = instance.format_search_results(
        results,
        empty_message: "No results.",
        item_formatter:,
        max_results: 1
      )

      expect(output).to include("Found 1 result")
    end
  end
end
