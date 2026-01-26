require "spec_helper"

RSpec.describe Smolagents::Concerns::Results::Formatting do
  subject(:formatter) { test_class.new }

  let(:test_class) do
    Class.new do
      # Formatting depends on Messages for build_results_output and empty_results_message
      include Smolagents::Concerns::Results::Messages
      include Smolagents::Concerns::Results::Formatting
    end
  end

  describe "#format_results" do
    let(:results) do
      [
        { title: "Ruby 4.0", link: "https://ruby-lang.org", description: "Latest version" },
        { title: "Rails 8", link: "https://rubyonrails.org", description: "Framework update" }
      ]
    end

    context "with basic formatting" do
      it "formats results as markdown links" do
        output = formatter.format_results(results)

        expect(output).to include("[Ruby 4.0](https://ruby-lang.org)")
        expect(output).to include("[Rails 8](https://rubyonrails.org)")
      end

      it "includes descriptions" do
        output = formatter.format_results(results)

        expect(output).to include("Latest version")
        expect(output).to include("Framework update")
      end

      it "includes results count" do
        output = formatter.format_results(results)
        expect(output).to include("Found 2 results")
      end
    end

    context "with indexed format" do
      it "numbers results when indexed: true" do
        output = formatter.format_results(results, indexed: true)

        expect(output).to include("1. [Ruby 4.0]")
        expect(output).to include("2. [Rails 8]")
      end

      it "respects indexed: false" do
        output = formatter.format_results(results, indexed: false)

        expect(output).not_to match(/^\d+\./)
      end
    end

    context "with custom field names" do
      let(:custom_results) do
        [
          { name: "Item 1", url: "http://a.com", summary: "Description 1" }
        ]
      end

      it "maps custom title field" do
        output = formatter.format_results(custom_results, title: :name, link: :url)

        expect(output).to include("[Item 1]")
      end

      it "maps custom description field" do
        output = formatter.format_results(custom_results, title: :name, link: :url, description: :summary)

        expect(output).to include("Description 1")
      end
    end

    context "with custom header" do
      it "uses provided header" do
        output = formatter.format_results(results, header: "## Search Results")

        expect(output).to include("## Search Results")
      end

      it "includes default header without customization" do
        output = formatter.format_results(results)

        expect(output).to include("Found")
      end
    end

    context "with empty results" do
      it "returns empty message for empty array" do
        output = formatter.format_results([])

        expect(output).to include("No results found")
      end

      it "returns empty message for nil" do
        output = formatter.format_results(nil)

        expect(output).to include("No results found")
      end
    end

    context "with metadata formatting" do
      let(:metadata_results) do
        [
          {
            title: "Article 1",
            link: "http://a.com",
            date: "2024-01-15",
            snippet: "This is a preview..."
          },
          {
            title: "Article 2",
            link: "http://b.com",
            date: "2024-01-14",
            snippet: "Another preview..."
          }
        ]
      end

      it "includes date when include_metadata: true" do
        # Need to specify symbol keys since results use symbols
        output = formatter.format_results(
          metadata_results,
          include_metadata: true,
          title: :title,
          link: :link,
          date: :date,
          snippet: :snippet
        )

        expect(output).to include("Date: 2024-01-15")
        expect(output).to include("Date: 2024-01-14")
      end

      it "includes snippet when include_metadata: true" do
        output = formatter.format_results(
          metadata_results,
          include_metadata: true,
          title: :title,
          link: :link,
          date: :date,
          snippet: :snippet
        )

        expect(output).to include("This is a preview...")
        expect(output).to include("Another preview...")
      end

      it "numbers results in metadata format" do
        output = formatter.format_results(
          metadata_results,
          include_metadata: true,
          title: :title,
          link: :link,
          date: :date,
          snippet: :snippet
        )

        expect(output).to include("1. [Article 1]")
        expect(output).to include("2. [Article 2]")
      end
    end

    context "with custom field mappings and metadata" do
      let(:api_results) do
        [
          {
            headline: "News 1",
            url: "http://news1.com",
            published: "2024-01-15",
            excerpt: "Breaking news"
          }
        ]
      end

      it "maps custom fields with metadata" do
        output = formatter.format_results(
          api_results,
          include_metadata: true,
          title: :headline,
          link: :url,
          date: :published,
          snippet: :excerpt
        )

        expect(output).to include("[News 1]")
        expect(output).to include("Date: 2024-01-15")
        expect(output).to include("Breaking news")
      end
    end

    context "with ResultFormatConfig" do
      it "accepts a configuration object" do
        config = Smolagents::Types::ResultFormatConfig.create(indexed: true)
        output = formatter.format_results(results, config)

        expect(output).to include("1. [Ruby 4.0]")
      end

      it "uses config metadata settings" do
        # with_metadata uses symbol keys by default when we override them
        config = Smolagents::Types::ResultFormatConfig.with_metadata(
          title: :title,
          link: :link,
          date: :date,
          snippet: :snippet
        )
        metadata_results = [
          { title: "Test", link: "http://test.com", date: "2024-01-15", snippet: "Info" }
        ]
        output = formatter.format_results(metadata_results, config)

        expect(output).to include("Date: 2024-01-15")
        expect(output).to include("Info")
      end
    end
  end

  describe "#format_results_with_metadata" do
    let(:results) do
      [
        { title: "Article 1", link: "http://a.com", date: "2024-01-15", snippet: "Content 1" },
        { title: "Article 2", link: "http://b.com", date: "2024-01-14", snippet: "Content 2" }
      ]
    end

    it "formats with metadata by default" do
      # Need to specify symbol keys since results use symbols
      output = formatter.format_results_with_metadata(
        results,
        title: :title,
        link: :link,
        date: :date,
        snippet: :snippet
      )

      expect(output).to include("Date: 2024-01-15")
      expect(output).to include("Content 1")
    end

    it "supports custom field names" do
      custom = [{ name: "Item", url: "http://x.com", published: "today", info: "Details" }]
      output = formatter.format_results_with_metadata(
        custom,
        title: :name,
        link: :url,
        date: :published,
        snippet: :info
      )

      expect(output).to include("[Item]")
      expect(output).to include("Date: today")
      expect(output).to include("Details")
    end

    it "returns empty message for empty results" do
      output = formatter.format_results_with_metadata([])
      expect(output).to include("No results found")
    end

    it "uses indexed format by default" do
      output = formatter.format_results_with_metadata(
        results,
        title: :title,
        link: :link,
        date: :date,
        snippet: :snippet
      )
      expect(output).to include("1. [Article 1]")
    end
  end

  describe "private methods" do
    describe "#resolve_format_config" do
      let(:results) { [{ title: "Test", link: "http://test.com" }] }

      it "returns config as-is if already a ResultFormatConfig" do
        config = Smolagents::Types::ResultFormatConfig.create(indexed: true)
        resolved = formatter.send(:resolve_format_config, config)

        expect(resolved).to be(config)
      end

      it "creates ResultFormatConfig from options" do
        resolved = formatter.send(:resolve_format_config, nil, indexed: true)

        expect(resolved).to be_a(Smolagents::Types::ResultFormatConfig)
      end

      it "creates with_metadata config when flag set" do
        resolved = formatter.send(:resolve_format_config, nil, include_metadata: true)

        expect(resolved.metadata_format?).to be true
      end
    end

    describe "#format_result_lines" do
      let(:results) do
        [
          { title: "A", link: "http://a.com" },
          { title: "B", link: "http://b.com" }
        ]
      end

      it "formats each result with index" do
        config = Smolagents::Types::ResultFormatConfig.create(indexed: true)
        lines = formatter.send(:format_result_lines, results, config)

        expect(lines.size).to eq(2)
        expect(lines[0]).to include("1.")
        expect(lines[1]).to include("2.")
      end
    end

    describe "#format_result_line" do
      let(:result) { { title: "Title", link: "http://test.com", description: "Desc" } }

      it "formats basic result line" do
        config = Smolagents::Types::ResultFormatConfig.create(indexed: false)
        line = formatter.send(:format_result_line, result, 1, config)

        expect(line).to include("[Title](http://test.com)")
      end

      it "formats with index when configured" do
        config = Smolagents::Types::ResultFormatConfig.create(indexed: true)
        line = formatter.send(:format_result_line, result, 3, config)

        expect(line).to start_with("3.")
      end

      it "formats with metadata when configured" do
        config = Smolagents::Types::ResultFormatConfig.with_metadata(
          title: :title, link: :link, date: :date, snippet: :snippet
        )
        result_with_meta = result.merge(date: "2024-01-15", snippet: "Info")
        line = formatter.send(:format_result_line, result_with_meta, 1, config)

        expect(line).to include("Date: 2024-01-15")
        expect(line).to include("Info")
      end
    end

    describe "#format_basic" do
      let(:result) { { title: "Title", link: "http://test.com", description: "Description" } }

      it "formats link and description" do
        config = Smolagents::Types::ResultFormatConfig.create(indexed: false)
        line = formatter.send(:format_basic, result, 1, config)

        expect(line).to include("[Title](http://test.com)")
        expect(line).to include("Description")
      end

      it "includes index when indexed" do
        config = Smolagents::Types::ResultFormatConfig.create(indexed: true)
        line = formatter.send(:format_basic, result, 5, config)

        expect(line).to start_with("5.")
      end
    end

    describe "#format_with_metadata" do
      let(:result) do
        {
          title: "Article",
          link: "http://article.com",
          date: "2024-01-15",
          snippet: "Preview text"
        }
      end

      it "includes all metadata fields" do
        config = Smolagents::Types::ResultFormatConfig.with_metadata(
          title: :title, link: :link, date: :date, snippet: :snippet
        )
        line = formatter.send(:format_with_metadata, result, 1, config)

        expect(line).to include("1. [Article]")
        expect(line).to include("Date: 2024-01-15")
        expect(line).to include("Preview text")
      end

      it "handles missing date" do
        config = Smolagents::Types::ResultFormatConfig.with_metadata(
          title: :title, link: :link, date: :date, snippet: :snippet
        )
        result_no_date = result.except(:date)
        line = formatter.send(:format_with_metadata, result_no_date, 1, config)

        expect(line).not_to include("Date:")
      end
    end

    describe "#append_description" do
      it "appends description with newline" do
        line = "[Title](http://link.com)"
        result = formatter.send(:append_description, line, "Description text")

        expect(result).to include(line)
        expect(result).to include("\n")
        expect(result).to include("Description text")
      end

      it "ignores empty description" do
        line = "[Title](http://link.com)"
        result = formatter.send(:append_description, line, "")

        expect(result).to eq(line)
      end

      it "ignores nil description" do
        line = "[Title](http://link.com)"
        result = formatter.send(:append_description, line, nil)

        expect(result).to eq(line)
      end
    end
  end
end
