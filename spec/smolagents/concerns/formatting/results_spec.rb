require "rspec"
require_relative "../../../../lib/smolagents/types/result_format_config"
require_relative "../../../../lib/smolagents/concerns/formatting/results"

RSpec.describe Smolagents::Concerns::Results do
  subject(:formatter) { test_class.new }

  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::Results
    end
  end

  describe "module composition" do
    it "includes Extraction" do
      expect(test_class.ancestors).to include(Smolagents::Concerns::Results::Extraction)
    end

    it "includes Messages" do
      expect(test_class.ancestors).to include(Smolagents::Concerns::Results::Messages)
    end

    it "includes Formatting" do
      expect(test_class.ancestors).to include(Smolagents::Concerns::Results::Formatting)
    end
  end

  describe "#map_results" do
    it "maps string keys" do
      data = [{ "name" => "Test", "url" => "http://test.com" }]
      result = formatter.map_results(data, title: "name", link: "url")

      expect(result).to eq([{ title: "Test", link: "http://test.com" }])
    end

    it "maps with procs" do
      data = [{ "name" => "test" }]
      result = formatter.map_results(data, title: ->(r) { r["name"].upcase })

      expect(result).to eq([{ title: "TEST" }])
    end

    it "maps with array paths for dig" do
      data = [{ "nested" => { "value" => "deep" } }]
      result = formatter.map_results(data, val: %w[nested value])

      expect(result).to eq([{ val: "deep" }])
    end

    it "handles nil input" do
      expect(formatter.map_results(nil, title: "name")).to eq([])
    end
  end

  describe "#extract_and_map" do
    it "extracts from nested path and maps" do
      data = { "response" => { "items" => [{ "title" => "Item 1" }] } }
      result = formatter.extract_and_map(data, path: %w[response items], name: "title")

      expect(result).to eq([{ name: "Item 1" }])
    end

    it "returns empty array for missing path" do
      data = { "other" => "data" }
      result = formatter.extract_and_map(data, path: %w[missing path], name: "title")

      expect(result).to eq([])
    end
  end

  describe "#format_results" do
    let(:results) do
      [
        { title: "Result 1", link: "http://a.com", description: "Desc 1" },
        { title: "Result 2", link: "http://b.com", description: "Desc 2" }
      ]
    end

    it "formats results as markdown" do
      output = formatter.format_results(results)

      expect(output).to include("[Result 1](http://a.com)")
      expect(output).to include("Desc 1")
      expect(output).to include("Found 2 results")
    end

    it "returns empty message for empty results" do
      output = formatter.format_results([])

      expect(output).to include("No results found")
    end

    it "supports indexed format" do
      output = formatter.format_results(results, indexed: true)

      expect(output).to include("1. [Result 1]")
      expect(output).to include("2. [Result 2]")
    end

    it "supports custom header" do
      output = formatter.format_results(results, header: "## Custom Header")

      expect(output).to include("## Custom Header")
    end

    it "accepts ResultFormatConfig" do
      config = Smolagents::Types::ResultFormatConfig.create(indexed: true)
      output = formatter.format_results(results, config)

      expect(output).to include("1. [Result 1]")
    end
  end

  describe "#format_results_with_metadata" do
    let(:results) do
      [
        { "title" => "News 1", "link" => "http://news.com", "date" => "2024-01-15", "snippet" => "Breaking news" }
      ]
    end

    it "formats with date and snippet" do
      output = formatter.format_results_with_metadata(results)

      expect(output).to include("[News 1](http://news.com)")
      expect(output).to include("Date: 2024-01-15")
      expect(output).to include("Breaking news")
    end

    it "returns message for empty results" do
      output = formatter.format_results_with_metadata([])

      expect(output).to include("No results found")
    end

    it "supports custom field mappings" do
      data = [{ "headline" => "Story", "url" => "http://x.com", "published" => "today" }]
      output = formatter.format_results_with_metadata(data, title: "headline", link: "url", date: "published")

      expect(output).to include("[Story](http://x.com)")
      expect(output).to include("Date: today")
    end
  end

  describe "constants" do
    it "defines EMPTY_RESULTS_MESSAGE" do
      expect(Smolagents::Concerns::Results::Messages::EMPTY_RESULTS_MESSAGE).to include("No results found")
    end

    it "defines RESULTS_NEXT_STEPS" do
      expect(Smolagents::Concerns::Results::Messages::RESULTS_NEXT_STEPS).to include("NEXT STEPS")
    end

    it "defines MESSAGE_TEMPLATES hash" do
      templates = Smolagents::Concerns::Results::Messages::MESSAGE_TEMPLATES

      expect(templates[:empty]).to eq(Smolagents::Concerns::Results::Messages::EMPTY_RESULTS_MESSAGE)
      expect(templates[:next_steps]).to eq(Smolagents::Concerns::Results::Messages::RESULTS_NEXT_STEPS)
    end
  end
end
