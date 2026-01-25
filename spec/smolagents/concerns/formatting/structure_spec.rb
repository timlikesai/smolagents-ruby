require "spec_helper"

RSpec.describe Smolagents::Concerns::StructureFormatting do
  describe "module constants" do
    it "defines MAX_SAMPLE limit" do
      expect(described_class::MAX_SAMPLE).to eq(300)
    end

    it "defines MAX_KEYS limit" do
      expect(described_class::MAX_KEYS).to eq(8)
    end

    it "defines MAX_DEPTH limit" do
      expect(described_class::MAX_DEPTH).to eq(3)
    end

    it "defines MAX_INLINE_ARRAY limit" do
      expect(described_class::MAX_INLINE_ARRAY).to eq(10)
    end
  end

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

    context "with ranges" do
      it "formats ranges with inspect" do
        expect(described_class.describe(1..10)).to eq("result = 1..10")
      end

      it "formats exclusive ranges" do
        expect(described_class.describe(1...10)).to eq("result = 1...10")
      end
    end

    context "with strings" do
      it "formats short strings with value" do
        expect(described_class.describe("hello")).to eq('result = "hello"')
      end

      it "truncates long strings" do
        long_string = "x" * 200
        result = described_class.describe(long_string)
        expect(result).to eq("result = String(200 chars)")
      end

      it "formats strings at 80 char boundary with value" do
        str = "x" * 80
        result = described_class.describe(str)
        expect(result).to eq("result = \"#{str}\"")
      end

      it "truncates strings over 80 chars" do
        str = "x" * 81
        result = described_class.describe(str)
        expect(result).to eq("result = String(81 chars)")
      end
    end

    context "with arrays" do
      it "formats empty arrays" do
        expect(described_class.describe([])).to eq("result = [] (empty array)")
      end

      it "formats small arrays of primitives inline" do
        result = described_class.describe([1, 2, 3])
        expect(result).to eq("result = [1, 2, 3]")
      end

      it "formats arrays up to MAX_INLINE_ARRAY inline" do
        arr = (1..10).to_a
        result = described_class.describe(arr)
        expect(result).to eq("result = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]")
      end

      it "formats large arrays of primitives with summary" do
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
        result = described_class.describe([1, "two", :three])
        expect(result).to eq('result = [1, "two", :three]')
      end

      it "shows mixed types in summary for larger arrays" do
        arr = [1, "two", :three] * 5
        result = described_class.describe(arr)
        expect(result).to include("Elements: Mixed")
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

      it "limits keys shown to MAX_KEYS" do
        data = (1..12).to_h { |i| ["key#{i}", i] }
        result = described_class.describe(data)

        expect(result).to include("...")
        expect(result).not_to include('"key12"')
      end

      it "limits hash entries shown to 4" do
        data = { a: 1, b: 2, c: 3, d: 4, e: 5 }
        result = described_class.describe(data)

        lines = result.split("\n")
        entry_lines = lines.reject { |l| l.include?("Hash with keys") }
        expect(entry_lines.size).to eq(4)
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

      it "uses provided variable name for hashes" do
        result = described_class.describe({ a: 1 }, var: "data")
        expect(result).to include("data = Hash with keys:")
        expect(result).to include("data[:a]")
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

      it "formats objects responding to to_a" do
        obj = (1..3)
        result = described_class.describe(obj)
        # Range gets described via describe_range, not describe_object
        expect(result).to eq("result = 1..3")
      end

      it "formats objects with neither to_h nor to_a" do
        obj = Object.new
        result = described_class.describe(obj)
        expect(result).to eq("result = Object")
      end
    end

    context "with depth limiting" do
      it "respects MAX_DEPTH for nested structures" do
        deeply_nested = { a: { b: { c: { d: { e: 1 } } } } }
        result = described_class.describe(deeply_nested)

        # At depth 2, it should show Hash[n keys] instead of expanding further
        expect(result).to include("Hash[1 keys]")
      end
    end
  end

  # Sub-module tests - these test internal implementation details
  describe "Primitives sub-module" do
    let(:primitives) { described_class::Primitives }

    describe ".describe_range" do
      it "formats inclusive ranges" do
        expect(primitives.describe_range(1..5, "r")).to eq("r = 1..5")
      end

      it "formats exclusive ranges" do
        expect(primitives.describe_range(1...5, "r")).to eq("r = 1...5")
      end
    end

    describe ".describe_primitive" do
      it "formats nil" do
        expect(primitives.describe_primitive(nil, "x")).to eq("x = nil")
      end

      it "formats symbols with inspect" do
        expect(primitives.describe_primitive(:foo, "x")).to eq("x = :foo")
      end

      it "formats integers directly" do
        expect(primitives.describe_primitive(42, "x")).to eq("x = 42")
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

      it "formats integer keys" do
        expect(helpers.accessor(0)).to eq("[0]")
      end
    end

    describe ".format_key" do
      it "formats symbol keys with colon prefix" do
        expect(helpers.format_key(:name)).to eq(":name")
      end

      it "formats string keys with quotes" do
        expect(helpers.format_key("name")).to eq('"name"')
      end
    end

    describe ".format_keys" do
      it "formats keys up to MAX_KEYS" do
        keys = (1..8).map { |i| "key#{i}" }
        result = helpers.format_keys(keys)
        expect(result).not_to include("...")
      end

      it "adds ellipsis for keys beyond MAX_KEYS" do
        keys = (1..10).map { |i| "key#{i}" }
        result = helpers.format_keys(keys)
        expect(result).to include("...")
      end
    end

    describe ".sample" do
      it "returns short values as-is" do
        expect(helpers.sample("hello")).to eq('"hello"')
      end

      it "truncates long values at MAX_SAMPLE" do
        long_value = "x" * 500
        result = helpers.sample(long_value)

        expect(result.length).to be <= 305
        expect(result).to end_with("...")
      end

      it "handles inspect errors gracefully" do
        obj = Object.new
        def obj.inspect = raise("boom")

        expect(helpers.sample(obj)).to eq("?")
      end
    end
  end

  describe "Arrays sub-module" do
    let(:arrays) { described_class::Arrays }

    describe ".all_primitives?" do
      it "returns true for array of primitives" do
        expect(arrays.all_primitives?([1, "two", :three, nil, true, false])).to be(true)
      end

      it "returns false for array containing hash" do
        expect(arrays.all_primitives?([1, { a: 1 }])).to be(false)
      end

      it "returns false for array containing array" do
        expect(arrays.all_primitives?([1, [2, 3]])).to be(false)
      end
    end
  end
end
