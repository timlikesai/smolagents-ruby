# frozen_string_literal: true

RSpec.describe Smolagents::ToolResult do
  let(:array_data) { [{ name: "Alice", age: 30 }, { name: "Bob", age: 25 }, { name: "Charlie", age: 35 }] }
  let(:result) { described_class.new(array_data, tool_name: "test_tool") }

  describe "#initialize" do
    it "creates a result with data and tool name" do
      expect(result.data).to eq(array_data)
      expect(result.tool_name).to eq("test_tool")
    end

    it "freezes the data for immutability" do
      expect(result.data).to be_frozen
      expect(result.data.first).to be_frozen
    end

    it "includes created_at in metadata" do
      expect(result.metadata[:created_at]).to be_a(Time)
    end

    it "accepts additional metadata" do
      result = described_class.new([], tool_name: "test", metadata: { query: "search term" })
      expect(result.metadata[:query]).to eq("search term")
    end

    it "accepts symbol tool_name" do
      result = described_class.new([], tool_name: :my_tool)
      expect(result.tool_name).to eq("my_tool")
    end
  end

  describe "Enumerable" do
    it "includes Enumerable" do
      expect(described_class.ancestors).to include(Enumerable)
    end

    it "iterates over array data" do
      names = []
      result.each { |item| names << item[:name] }
      expect(names).to eq(%w[Alice Bob Charlie])
    end

    it "iterates over hash data" do
      hash_result = described_class.new({ a: 1, b: 2 }, tool_name: "test")
      pairs = []
      hash_result.each { |k, v| pairs << [k, v] }
      expect(pairs).to eq([[:a, 1], [:b, 2]])
    end

    it "yields single value for scalar data" do
      scalar_result = described_class.new("hello", tool_name: "test")
      values = []
      scalar_result.each { |v| values << v }
      expect(values).to eq(["hello"])
    end

    it "returns Enumerator when no block given" do
      expect(result.each).to be_a(Enumerator)
    end

    it "supports standard Enumerable methods" do
      expect(result.count).to eq(3)
      expect(result.find { |item| item[:name] == "Bob" }).to eq({ name: "Bob", age: 25 })
      expect(result.reduce(0) { |sum, item| sum + item[:age] }).to eq(90)
    end
  end

  describe "#size" do
    it "returns array size for array data" do
      array_result = described_class.new([1, 2, 3], tool_name: "test")
      expect(array_result.size).to eq(3)
    end

    it "returns hash size for hash data" do
      hash_result = described_class.new({ a: 1, b: 2 }, tool_name: "test")
      expect(hash_result.size).to eq(2)
    end

    it "returns 1 for string scalar data" do
      string_result = described_class.new("hello", tool_name: "test")
      expect(string_result.size).to eq(1)
    end

    it "returns 1 for number scalar data" do
      number_result = described_class.new(42, tool_name: "test")
      expect(number_result.size).to eq(1)
    end

    it "returns 0 for nil data" do
      nil_result = described_class.new(nil, tool_name: "test")
      expect(nil_result.size).to eq(0)
    end

    it "returns 1 for other scalar types" do
      symbol_result = described_class.new(:test_symbol, tool_name: "test")
      expect(symbol_result.size).to eq(1)
    end

    it "is aliased as length" do
      expect(result.length).to eq(result.size)
    end

    it "is aliased as count" do
      expect(result.count).to eq(result.size)
    end
  end

  describe "#select" do
    it "returns a new ToolResult with filtered data" do
      filtered = result.select { |item| item[:age] >= 30 }

      expect(filtered).to be_a(described_class)
      expect(filtered.count).to eq(2)
      expect(filtered.map { |i| i[:name] }.to_a).to eq(%w[Alice Charlie])
    end

    it "preserves tool_name" do
      filtered = result.select { |_| true }
      expect(filtered.tool_name).to eq("test_tool")
    end

    it "is aliased as filter" do
      expect(result.method(:filter)).to eq(result.method(:select))
    end
  end

  describe "#reject" do
    it "returns a new ToolResult without matching elements" do
      rejected = result.reject { |item| item[:age] < 30 }

      expect(rejected.count).to eq(2)
      expect(rejected.map { |i| i[:name] }.to_a).to eq(%w[Alice Charlie])
    end
  end

  describe "#map" do
    it "transforms each element" do
      names = result.map { |item| item[:name] }

      expect(names).to be_a(described_class)
      expect(names.to_a).to eq(%w[Alice Bob Charlie])
    end

    it "works with scalar data" do
      scalar = described_class.new("hello", tool_name: "test")
      transformed = scalar.map(&:upcase)
      expect(transformed.data).to eq("HELLO")
    end
  end

  describe "#flat_map" do
    it "maps and flattens" do
      nested = described_class.new([[1, 2], [3, 4]], tool_name: "test")
      flat = nested.flat_map { |arr| arr.map { |x| x * 2 } }
      expect(flat.to_a).to eq([2, 4, 6, 8])
    end
  end

  describe "#sort_by" do
    it "sorts elements by block result" do
      sorted = result.sort_by { |item| item[:age] }
      expect(sorted.map { |i| i[:name] }.to_a).to eq(%w[Bob Alice Charlie])
    end

    it "supports descending sort via negation" do
      sorted = result.sort_by { |item| -item[:age] }
      expect(sorted.map { |i| i[:name] }.to_a).to eq(%w[Charlie Alice Bob])
    end
  end

  describe "#reverse" do
    it "reverses element order" do
      reversed = result.reverse
      expect(reversed.map { |i| i[:name] }.to_a).to eq(%w[Charlie Bob Alice])
    end
  end

  describe "#uniq" do
    it "removes duplicates" do
      duped = described_class.new([1, 2, 2, 3, 3, 3], tool_name: "test")
      expect(duped.uniq.to_a).to eq([1, 2, 3])
    end

    it "removes duplicates by block" do
      expect(result.uniq { |i| i[:age] >= 30 }.count).to eq(2)
    end
  end

  describe "#compact" do
    it "removes nil elements" do
      with_nils = described_class.new([1, nil, 2, nil, 3], tool_name: "test")
      expect(with_nils.compact.to_a).to eq([1, 2, 3])
    end
  end

  describe "#flatten" do
    it "flattens nested arrays" do
      nested = described_class.new([[1, [2]], [3]], tool_name: "test")
      expect(nested.flatten.to_a).to eq([1, 2, 3])
    end

    it "respects depth parameter" do
      nested = described_class.new([[1, [2]], [3]], tool_name: "test")
      expect(nested.flatten(1).to_a).to eq([1, [2], 3])
    end
  end

  describe "#take and #drop" do
    it "takes first n elements" do
      expect(result.take(2).to_a.map { |i| i[:name] }).to eq(%w[Alice Bob])
    end

    it "drops first n elements" do
      expect(result.drop(1).to_a.map { |i| i[:name] }).to eq(%w[Bob Charlie])
    end
  end

  describe "#take_while and #drop_while" do
    it "takes while condition is true" do
      numbers = described_class.new([1, 2, 3, 4, 5], tool_name: "test")
      expect(numbers.take_while { |n| n < 4 }.to_a).to eq([1, 2, 3])
    end

    it "drops while condition is true" do
      numbers = described_class.new([1, 2, 3, 4, 5], tool_name: "test")
      expect(numbers.drop_while { |n| n < 4 }.to_a).to eq([4, 5])
    end
  end

  describe "#group_by" do
    it "groups elements by block result" do
      grouped = result.group_by { |item| item[:age] >= 30 }
      expect(grouped.data[true].size).to eq(2)
      expect(grouped.data[false].size).to eq(1)
    end
  end

  describe "#partition" do
    it "splits into matching and non-matching" do
      matching, non_matching = result.partition { |item| item[:age] >= 30 }

      expect(matching).to be_a(described_class)
      expect(non_matching).to be_a(described_class)
      expect(matching.count).to eq(2)
      expect(non_matching.count).to eq(1)
    end
  end

  describe "#first and #last" do
    it "returns first element without argument" do
      expect(result.first).to eq({ name: "Alice", age: 30 })
    end

    it "returns ToolResult with first n elements" do
      first_two = result.first(2)
      expect(first_two).to be_a(described_class)
      expect(first_two.count).to eq(2)
    end

    it "returns last element without argument" do
      expect(result.last).to eq({ name: "Charlie", age: 35 })
    end

    it "returns ToolResult with last n elements" do
      last_two = result.last(2)
      expect(last_two).to be_a(described_class)
      expect(last_two.count).to eq(2)
    end
  end

  describe "#pluck" do
    it "extracts values for a key" do
      names = result.pluck(:name)
      expect(names.to_a).to eq(%w[Alice Bob Charlie])
    end

    it "handles string keys" do
      string_keys = described_class.new([{ "name" => "Test" }], tool_name: "test")
      expect(string_keys.pluck("name").to_a).to eq(["Test"])
    end
  end

  describe "#dig" do
    it "digs into nested structures" do
      nested = described_class.new({ a: { b: { c: 42 } } }, tool_name: "test")
      expect(nested.dig(:a, :b, :c)).to eq(42)
    end

    it "returns nil for missing paths" do
      expect(result.dig(:missing, :path)).to be_nil
    end
  end

  describe "aggregation methods" do
    let(:numbers) { described_class.new([1, 2, 3, 4, 5], tool_name: "test") }

    it "sums values" do
      expect(numbers.sum).to eq(15)
    end

    it "sums with block" do
      expect(result.sum { |item| item[:age] }).to eq(90)
    end

    it "finds min" do
      expect(numbers.min).to eq(1)
      # Our min uses min_by semantics (single-arg block) not comparison (two-arg block)
      expect(result.min { |item| item[:age] }).to eq({ name: "Bob", age: 25 }) # rubocop:disable Lint/UnexpectedBlockArity
    end

    it "finds max" do
      expect(numbers.max).to eq(5)
      # Our max uses max_by semantics (single-arg block) not comparison (two-arg block)
      expect(result.max { |item| item[:age] }).to eq({ name: "Charlie", age: 35 }) # rubocop:disable Lint/UnexpectedBlockArity
    end

    it "calculates average" do
      expect(numbers.average).to eq(3.0)
      expect(result.average { |item| item[:age] }).to eq(30.0)
    end
  end

  describe "predicates" do
    it "checks empty?" do
      expect(result.empty?).to be false
      expect(described_class.new([], tool_name: "test").empty?).to be true
      expect(described_class.new(nil, tool_name: "test").empty?).to be true
    end

    it "checks any?" do
      expect(result.any?).to be true
      expect(result.any? { |item| item[:age] > 40 }).to be false
    end

    it "checks all?" do
      expect(result.all? { |item| item[:age] > 20 }).to be true
      expect(result.all? { |item| item[:age] > 30 }).to be false
    end

    it "checks none?" do
      expect(result.none? { |item| item[:age] > 50 }).to be true
    end

    it "checks one?" do
      expect(result.one? { |item| item[:name] == "Alice" }).to be true
    end

    it "checks include?" do
      numbers = described_class.new([1, 2, 3], tool_name: "test")
      expect(numbers.include?(2)).to be true
      expect(numbers.include?(5)).to be false
    end
  end

  describe "conversions" do
    it "converts to array" do
      expect(result.to_a).to eq(array_data)
      expect(result.to_a).not_to equal(result.data) # returns copy
    end

    it "converts hash to array of pairs" do
      hash_result = described_class.new({ a: 1, b: 2 }, tool_name: "test")
      expect(hash_result.to_a).to eq([[:a, 1], [:b, 2]])
    end

    it "converts to hash" do
      h = result.to_h
      expect(h[:data]).to eq(array_data)
      expect(h[:tool_name]).to eq("test_tool")
      expect(h[:metadata]).to be_a(Hash)
    end

    it "converts to string for LLM" do
      expect(result.to_s).to be_a(String)
      expect(result.to_s).to include("Alice")
    end

    it "converts to JSON" do
      json = result.to_json
      expect(JSON.parse(json)).to eq(array_data.map { |h| h.transform_keys(&:to_s) })
    end
  end

  describe "output formats" do
    describe "#as_markdown" do
      it "formats array of hashes as structured list" do
        md = result.as_markdown
        expect(md).to include("**1.**")
        expect(md).to include("**name:** Alice")
      end

      it "formats simple array as bullet list" do
        simple = described_class.new(%w[one two three], tool_name: "test")
        md = simple.as_markdown
        expect(md).to include("- one")
        expect(md).to include("- two")
      end

      it "respects max_items option" do
        md = result.as_markdown(max_items: 1)
        expect(md).to include("Alice")
        expect(md).not_to include("Bob")
      end
    end

    describe "#as_table" do
      it "formats array of hashes as ASCII table" do
        table = result.as_table
        expect(table).to include("name")
        expect(table).to include("age")
        expect(table).to include("Alice")
        expect(table).to include("---")
      end
    end

    describe "#as_list" do
      it "formats as bullet list" do
        list = result.as_list
        expect(list).to include("- name: Alice")
      end

      it "accepts custom bullet" do
        list = result.as_list(bullet: "*")
        expect(list).to include("* name: Alice")
      end
    end

    describe "#as_numbered_list" do
      it "formats as numbered list" do
        list = result.as_numbered_list
        expect(list).to include("1. name: Alice")
        expect(list).to include("2. name: Bob")
      end
    end
  end

  describe "composition" do
    describe "#+" do
      it "combines two results" do
        other = described_class.new([{ name: "Dave", age: 40 }], tool_name: "other")
        combined = result + other

        expect(combined.count).to eq(4)
        expect(combined.tool_name).to eq("test_tool+other")
      end
    end

    describe "#tap" do
      it "yields self and returns self" do
        tapped = nil
        returned = result.tap { |r| tapped = r }

        expect(tapped).to equal(result)
        expect(returned).to equal(result)
      end
    end

    describe "#then" do
      it "yields self and returns block result" do
        returned = result.then { |r| r.count * 2 }
        expect(returned).to eq(6)
      end
    end
  end

  describe "pattern matching" do
    it "supports array deconstruction" do
      case result
      in [first, *rest]
        expect(first[:name]).to eq("Alice")
        expect(rest.size).to eq(2)
      end
    end

    it "supports hash deconstruction" do
      case result
      in { data:, tool_name: "test_tool" }
        expect(data).to eq(array_data)
      else
        raise "Pattern should match"
      end
    end

    it "can match on nested data" do
      case result
      in { data: [{ name: "Alice", age: }, *] }
        expect(age).to eq(30)
      else
        raise "Pattern should match"
      end
    end
  end

  describe "equality and hashing" do
    it "equals another result with same data and tool_name" do
      other = described_class.new(array_data.dup, tool_name: "test_tool")
      expect(result).to eq(other)
    end

    it "does not equal result with different data" do
      other = described_class.new([{ name: "Different" }], tool_name: "test_tool")
      expect(result).not_to eq(other)
    end

    it "can be used as hash key" do
      hash = { result => "value" }
      other = described_class.new(array_data.dup, tool_name: "test_tool")
      expect(hash[other]).to eq("value")
    end
  end

  describe ".empty" do
    it "creates an empty result" do
      empty = described_class.empty(tool_name: "test")
      expect(empty.empty?).to be true
      expect(empty.tool_name).to eq("test")
    end
  end

  describe ".error" do
    it "creates an error result from exception" do
      error_result = described_class.error(
        StandardError.new("Something went wrong"),
        tool_name: "test"
      )

      expect(error_result.error?).to be true
      expect(error_result.success?).to be false
      expect(error_result.metadata[:error]).to include("Something went wrong")
    end

    it "creates an error result from string" do
      error_result = described_class.error("Failed", tool_name: "test")

      expect(error_result.error?).to be true
      expect(error_result.metadata[:error]).to eq("Failed")
    end
  end

  describe "#inspect" do
    it "returns a readable representation" do
      inspect_str = result.inspect
      expect(inspect_str).to include("ToolResult")
      expect(inspect_str).to include("test_tool")
      expect(inspect_str).to include("3 items")
    end

    it "truncates long strings" do
      long_string = "a" * 100
      str_result = described_class.new(long_string, tool_name: "test")
      expect(str_result.inspect).to include("...")
    end
  end

  describe "chaining" do
    it "supports method chaining" do
      processed = result
                  .select { |item| item[:age] >= 25 }
                  .sort_by { |item| item[:age] }
                  .map { |item| item[:name] }
                  .take(2)

      expect(processed.to_a).to eq(%w[Bob Alice])
    end

    it "preserves immutability through chain" do
      original_count = result.count
      result.select { |item| item[:age] > 30 }.map { |item| item[:name].upcase }
      expect(result.count).to eq(original_count)
    end
  end
end
