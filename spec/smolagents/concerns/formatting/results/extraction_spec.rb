require "spec_helper"

RSpec.describe Smolagents::Concerns::Results::Extraction do
  subject(:extractor) { test_class.new }

  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::Results::Extraction
    end
  end

  describe "#map_results" do
    context "with string keys" do
      let(:results) do
        [
          { "title" => "Article 1", "url" => "http://a.com", "author" => "Alice" },
          { "title" => "Article 2", "url" => "http://b.com", "author" => "Bob" }
        ]
      end

      it "maps string field names to symbols" do
        result = extractor.map_results(results, heading: "title", link: "url")

        expect(result).to eq([
                               { heading: "Article 1", link: "http://a.com" },
                               { heading: "Article 2", link: "http://b.com" }
                             ])
      end

      it "maps multiple fields" do
        result = extractor.map_results(results, title: "title", author: "author")

        expect(result[0]).to eq({ title: "Article 1", author: "Alice" })
      end
    end

    context "with Proc extractors" do
      let(:results) do
        [
          { "name" => "ruby", "version" => "4.0" },
          { "name" => "rails", "version" => "8.0" }
        ]
      end

      it "applies Proc to extract values" do
        result = extractor.map_results(results, name: "name", label: ->(r) { "#{r["name"]}-#{r["version"]}" })

        expect(result).to eq([
                               { name: "ruby", label: "ruby-4.0" },
                               { name: "rails", label: "rails-8.0" }
                             ])
      end

      it "can transform extracted values" do
        result = extractor.map_results(results, upper_name: ->(r) { r["name"].upcase })

        expect(result).to eq([
                               { upper_name: "RUBY" },
                               { upper_name: "RAILS" }
                             ])
      end

      it "handles Procs with nil returns" do
        result = extractor.map_results(
          [{ "val" => "test" }],
          optional: ->(r) { r["missing"] }
        )

        expect(result).to eq([{ optional: nil }])
      end
    end

    context "with Array paths (dig)" do
      let(:results) do
        [
          { "user" => { "profile" => { "name" => "Alice" } } },
          { "user" => { "profile" => { "name" => "Bob" } } }
        ]
      end

      it "extracts nested values using dig" do
        result = extractor.map_results(results, author: %w[user profile name])

        expect(result).to eq([
                               { author: "Alice" },
                               { author: "Bob" }
                             ])
      end

      it "returns nil for missing paths" do
        result = extractor.map_results(
          [{ "data" => { "x" => 1 } }],
          val: %w[data missing path]
        )

        expect(result).to eq([{ val: nil }])
      end

      it "handles single-element paths" do
        result = extractor.map_results(
          [{ "id" => 42 }],
          identifier: %w[id]
        )

        expect(result).to eq([{ identifier: 42 }])
      end
    end

    context "with mixed field types" do
      let(:results) do
        [
          {
            "title" => "Article",
            "metadata" => { "date" => "2024-01-15" },
            "score" => 9.5
          }
        ]
      end

      it "combines string, Proc, and Array specs" do
        result = extractor.map_results(
          results,
          headline: "title",
          publication_date: %w[metadata date],
          rating: ->(r) { (r["score"] * 10).to_i }
        )

        expect(result[0]).to eq({
                                  headline: "Article",
                                  publication_date: "2024-01-15",
                                  rating: 95
                                })
      end
    end

    context "with nil/empty input" do
      it "handles nil results" do
        result = extractor.map_results(nil, title: "title")
        expect(result).to eq([])
      end

      it "handles empty array" do
        result = extractor.map_results([], title: "title")
        expect(result).to eq([])
      end

      it "handles single result wrapped in array" do
        # NOTE: Array() on a Hash returns key-value pairs, not [hash]
        # So single results must be wrapped in an array by the caller
        result = extractor.map_results([{ "title" => "Single" }], name: "title")
        expect(result).to eq([{ name: "Single" }])
      end
    end

    context "with complex transformations" do
      let(:results) do
        [
          { "price" => "99.99", "currency" => "USD" },
          { "price" => "79.99", "currency" => "EUR" }
        ]
      end

      it "applies multiple Procs" do
        result = extractor.map_results(
          results,
          amount: ->(r) { r["price"].to_f },
          display: ->(r) { "#{r["currency"]} #{r["price"]}" }
        )

        expect(result[0]).to eq({ amount: 99.99, display: "USD 99.99" })
      end
    end
  end

  describe "#extract_and_map" do
    context "with nested response data" do
      let(:data) do
        {
          "status" => "success",
          "data" => {
            "results" => [
              { "id" => 1, "text" => "First" },
              { "id" => 2, "text" => "Second" }
            ]
          }
        }
      end

      it "extracts from nested path and maps" do
        result = extractor.extract_and_map(data, path: %w[data results], identifier: "id", content: "text")

        expect(result).to eq([
                               { identifier: 1, content: "First" },
                               { identifier: 2, content: "Second" }
                             ])
      end

      it "handles deep nesting" do
        deep_data = {
          "a" => { "b" => { "c" => { "items" => [{ "val" => "x" }, { "val" => "y" }] } } }
        }
        result = extractor.extract_and_map(deep_data, path: %w[a b c items], name: "val")

        expect(result).to eq([{ name: "x" }, { name: "y" }])
      end
    end

    context "with missing path" do
      let(:data) { { "other" => "data" } }

      it "returns empty array" do
        result = extractor.extract_and_map(data, path: %w[missing path], title: "name")
        expect(result).to eq([])
      end

      it "returns empty array for partial path" do
        data_with_partial = { "data" => { "wrong_key" => [] } }
        result = extractor.extract_and_map(data_with_partial, path: %w[data results], title: "name")
        expect(result).to eq([])
      end
    end

    context "with mixed extraction" do
      let(:data) do
        {
          "items" => [
            { "name" => "item1", "tags" => { "color" => "red" } },
            { "name" => "item2", "tags" => { "color" => "blue" } }
          ]
        }
      end

      it "combines extraction path with field mappings" do
        result = extractor.extract_and_map(
          data,
          path: %w[items],
          title: "name",
          color: %w[tags color]
        )

        expect(result).to eq([
                               { title: "item1", color: "red" },
                               { title: "item2", color: "blue" }
                             ])
      end
    end

    context "with Proc in extracted mapping" do
      let(:data) do
        {
          "items" => [
            { "price" => "19.99" }
          ]
        }
      end

      it "applies Procs to extracted data" do
        result = extractor.extract_and_map(
          data,
          path: %w[items],
          cost: ->(item) { item["price"].to_f * 1.1 }
        )

        expect(result[0][:cost]).to be_within(0.01).of(21.989)
      end
    end
  end

  describe "private methods" do
    describe "#extract_field" do
      let(:result) { { "name" => "test", "nested" => { "value" => "deep" } } }

      it "extracts string keys directly" do
        extracted = extractor.send(:extract_field, result, "name")
        expect(extracted).to eq("test")
      end

      it "extracts using Proc" do
        proc = ->(r) { r["name"].upcase }
        extracted = extractor.send(:extract_field, result, proc)
        expect(extracted).to eq("TEST")
      end

      it "extracts using Array paths" do
        extracted = extractor.send(:extract_field, result, %w[nested value])
        expect(extracted).to eq("deep")
      end

      it "returns nil for missing string keys" do
        extracted = extractor.send(:extract_field, result, "missing")
        expect(extracted).to be_nil
      end

      it "handles Proc errors gracefully" do
        failing_proc = ->(r) { r["missing"]["nested"] }
        expect do
          extractor.send(:extract_field, result, failing_proc)
        end.to raise_error(NoMethodError)
      end
    end
  end
end
