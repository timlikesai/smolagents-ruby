require "spec_helper"

RSpec.describe Smolagents::Concerns::StructureFormatting do
  describe ".describe" do
    context "with nil" do
      it "shows nil assignment" do
        expect(described_class.describe(nil)).to eq("result = nil")
      end
    end

    context "with booleans" do
      it "formats true" do
        expect(described_class.describe(true)).to eq("result = true")
      end

      it "formats false" do
        expect(described_class.describe(false)).to eq("result = false")
      end
    end

    context "with numbers" do
      it "formats integers" do
        expect(described_class.describe(42)).to eq("result = 42")
      end

      it "formats floats" do
        expect(described_class.describe(3.14)).to eq("result = 3.14")
      end
    end

    context "with symbols" do
      it "formats symbols with inspect" do
        expect(described_class.describe(:status)).to eq("result = :status")
      end
    end

    context "with strings" do
      it "formats short strings with value" do
        expect(described_class.describe("hello")).to eq('result = "hello"')
      end

      it "truncates long strings" do
        long_string = "x" * 200
        result = described_class.describe(long_string)

        expect(result).to include("result = String(200 chars)")
      end
    end

    context "with arrays" do
      it "formats empty arrays" do
        expect(described_class.describe([])).to eq("result = [] (empty array)")
      end

      it "formats small arrays of primitives inline" do
        # Small primitive arrays show actual values (critical for test assertions)
        result = described_class.describe([1, 2, 3])

        expect(result).to eq("result = [1, 2, 3]")
      end

      it "formats large arrays of primitives with summary" do
        # Large arrays still get summarized
        large_array = (1..15).to_a
        result = described_class.describe(large_array)

        expect(result).to include("result = Array[15]")
        expect(result).to include("Elements: Integer")
        expect(result).to include("First: 1")
      end

      it "formats arrays of hashes with access patterns" do
        data = [
          { "title" => "Ruby 4.0", "link" => "https://ruby-lang.org" },
          { "title" => "Rails 8", "link" => "https://rubyonrails.org" }
        ]
        result = described_class.describe(data)

        expect(result).to include("result = Array[2]")
        expect(result).to include('Each element has keys: "title", "link"')
        expect(result).to include("Access first: result[0] or result.first")
        expect(result).to include('result.first["title"] = "Ruby 4.0"')
      end

      it "formats arrays of hashes with symbol keys" do
        data = [{ title: "Test", count: 42 }]
        result = described_class.describe(data)

        expect(result).to include("Each element has keys: :title, :count")
        expect(result).to include("result.first[:title]")
      end

      it "shows mixed element types inline for small arrays" do
        # Small arrays with mixed primitives still show inline
        result = described_class.describe([1, "two", :three])

        expect(result).to eq('result = [1, "two", :three]')
      end
    end

    context "with hashes" do
      it "formats empty hashes" do
        expect(described_class.describe({})).to eq("result = {} (empty hash)")
      end

      it "formats hashes with access patterns" do
        data = { "name" => "Ruby", "version" => "4.0" }
        result = described_class.describe(data)

        expect(result).to include("result = Hash with keys:")
        expect(result).to include('result["name"] = "Ruby"')
        expect(result).to include('result["version"] = "4.0"')
      end

      it "formats hashes with symbol keys" do
        data = { name: "Ruby", version: "4.0" }
        result = described_class.describe(data)

        expect(result).to include("result[:name]")
        expect(result).to include("result[:version]")
      end

      it "shows nested hash paths" do
        data = {
          "user" => {
            "profile" => { "name" => "John" }
          }
        }
        result = described_class.describe(data)

        expect(result).to include('result["user"]["profile"]["name"] = "John"')
      end

      it "shows array within hash access patterns" do
        data = {
          "items" => [
            { "id" => 1, "name" => "First" }
          ]
        }
        result = described_class.describe(data)

        expect(result).to include('result["items"] = Array[1]')
        expect(result).to include('result["items"][0]["id"] = 1')
      end
    end

    context "with variable name" do
      it "uses provided variable name for small arrays" do
        result = described_class.describe([1, 2], var: "@results")

        expect(result).to eq("@results = [1, 2]")
      end

      it "uses provided variable name for large arrays" do
        result = described_class.describe((1..15).to_a, var: "@results")

        expect(result).to start_with("@results = Array[15]")
        expect(result).to include("@results[0]")
      end
    end

    context "with custom objects" do
      it "formats objects responding to to_h" do
        obj = Data.define(:name, :value).new("test", 42)
        result = described_class.describe(obj)

        expect(result).to include("result = Hash")
        expect(result).to include(":name")
        expect(result).to include(":value")
      end
    end
  end

  describe "Helpers sub-module" do
    let(:helpers) { described_class::Helpers }

    describe ".accessor" do
      it "formats symbol keys" do
        expect(helpers.accessor(:name)).to eq("[:name]")
      end

      it "formats string keys" do
        expect(helpers.accessor("name")).to eq('["name"]')
      end
    end

    describe ".sample" do
      it "returns short values as-is" do
        expect(helpers.sample("hello")).to eq('"hello"')
      end

      it "truncates long values" do
        long_value = "x" * 500
        result = helpers.sample(long_value)

        expect(result.length).to be <= 310
        expect(result).to end_with("...")
      end
    end
  end
end
