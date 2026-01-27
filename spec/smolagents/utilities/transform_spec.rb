RSpec.describe Smolagents::Utilities::Transform do
  describe Smolagents::Utilities::Transform::IndifferentHash do
    subject(:hash) { described_class["name" => "Alice", "age" => 30, "active" => true, "data" => nil] }

    describe "#[]" do
      it "accesses values with string keys" do
        expect(hash["name"]).to eq("Alice")
        expect(hash["age"]).to eq(30)
      end

      it "accesses values with symbol keys" do
        expect(hash[:name]).to eq("Alice")
        expect(hash[:age]).to eq(30)
      end

      it "returns nil for missing keys with either syntax" do
        expect(hash["missing"]).to be_nil
        expect(hash[:missing]).to be_nil
      end

      it "returns nil values correctly (doesn't confuse with missing)" do
        expect(hash["data"]).to be_nil
        expect(hash[:data]).to be_nil
        expect(hash.key?("data")).to be true
      end

      it "handles boolean false values" do
        hash_with_false = described_class["enabled" => false]

        expect(hash_with_false["enabled"]).to be false
        expect(hash_with_false[:enabled]).to be false
      end
    end

    describe "#key?" do
      it "finds keys with string syntax" do
        expect(hash.key?("name")).to be true
        expect(hash.key?("missing")).to be false
      end

      it "finds keys with symbol syntax" do
        expect(hash.key?(:name)).to be true
        expect(hash.key?(:missing)).to be false
      end
    end

    describe "#has_key?" do
      it "is aliased to key? with indifferent access" do
        expect(hash.has_key?("name")).to be true # rubocop:disable Style/PreferredHashMethods
        expect(hash.has_key?(:name)).to be true # rubocop:disable Style/PreferredHashMethods
      end
    end

    describe "#include?" do
      it "is aliased to key? with indifferent access" do
        expect(hash.include?("name")).to be true
        expect(hash.include?(:name)).to be true
      end
    end

    describe "#member?" do
      it "is aliased to key? with indifferent access" do
        expect(hash.member?("name")).to be true
        expect(hash.member?(:name)).to be true
      end
    end

    describe "#fetch" do
      it "fetches values with string keys" do
        expect(hash.fetch("name")).to eq("Alice")
      end

      it "fetches values with symbol keys" do
        expect(hash.fetch(:name)).to eq("Alice")
      end

      it "returns default for missing keys" do
        expect(hash.fetch("missing", "default")).to eq("default")
        expect(hash.fetch(:missing, "default")).to eq("default")
      end

      it "yields to block for missing keys" do
        expect(hash.fetch("missing") { "from_block" }).to eq("from_block")
        expect(hash.fetch(:missing) { "from_block" }).to eq("from_block")
      end

      it "raises KeyError for missing keys without default" do
        expect { hash.fetch("missing") }.to raise_error(KeyError)
        expect { hash.fetch(:missing) }.to raise_error(KeyError)
      end

      it "fetches nil values without triggering default" do
        expect(hash.fetch("data", "default")).to be_nil
        expect(hash.fetch(:data, "default")).to be_nil
      end
    end

    describe "inheritance" do
      it "is a Hash subclass" do
        expect(hash).to be_a(Hash)
      end

      it "supports standard Hash operations" do
        expect(hash.keys).to eq(%w[name age active data])
        expect(hash.values).to eq(["Alice", 30, true, nil])
        expect(hash.to_a).to eq([%w[name Alice], ["age", 30], ["active", true], ["data", nil]])
      end

      it "can be merged with regular hashes" do
        merged = hash.merge("extra" => "value")

        expect(merged["extra"]).to eq("value")
      end

      it "supports iteration" do
        keys = []
        hash.each_key { |k| keys << k }

        expect(keys).to eq(%w[name age active data])
      end
    end

    describe "edge cases" do
      it "handles integer keys" do
        int_hash = described_class[1 => "one", 2 => "two"]

        expect(int_hash[1]).to eq("one")
        expect(int_hash["1"]).to be_nil # Only symbol/string conversion
      end

      it "handles empty hash" do
        empty = described_class.new

        expect(empty[:missing]).to be_nil
        expect(empty.key?(:missing)).to be false
      end

      it "handles keys that look like method names" do
        hash_with_methods = described_class["class" => "MyClass", "method" => "call"]

        expect(hash_with_methods[:class]).to eq("MyClass")
        expect(hash_with_methods["method"]).to eq("call")
      end
    end
  end

  describe ".symbolize_keys" do
    it "converts string keys to symbols" do
      result = described_class.symbolize_keys({ "a" => 1, "b" => 2 })

      expect(result).to eq({ a: 1, b: 2 })
    end

    it "recursively symbolizes nested hashes" do
      result = described_class.symbolize_keys({ "outer" => { "inner" => 1 } })

      expect(result).to eq({ outer: { inner: 1 } })
    end

    it "symbolizes keys in arrays" do
      result = described_class.symbolize_keys([{ "a" => 1 }, { "b" => 2 }])

      expect(result).to eq([{ a: 1 }, { b: 2 }])
    end

    it "handles deeply nested structures" do
      input = { "l1" => [{ "l2" => { "l3" => [{ "l4" => "value" }] } }] }
      result = described_class.symbolize_keys(input)

      expect(result).to eq({ l1: [{ l2: { l3: [{ l4: "value" }] } }] })
    end

    it "passes through non-hash/array values unchanged" do
      expect(described_class.symbolize_keys("string")).to eq("string")
      expect(described_class.symbolize_keys(123)).to eq(123)
      expect(described_class.symbolize_keys(nil)).to be_nil
    end

    it "handles empty structures" do
      expect(described_class.symbolize_keys({})).to eq({})
      expect(described_class.symbolize_keys([])).to eq([])
    end
  end

  describe ".stringify_keys" do
    it "converts symbol keys to strings" do
      result = described_class.stringify_keys({ a: 1, b: 2 })

      expect(result["a"]).to eq(1)
      expect(result["b"]).to eq(2)
    end

    it "returns IndifferentHash instances" do
      result = described_class.stringify_keys({ a: 1 })

      expect(result).to be_a(described_class::IndifferentHash)
    end

    it "supports indifferent access on result" do
      result = described_class.stringify_keys({ name: "Alice", age: 30 })

      # String keys work
      expect(result["name"]).to eq("Alice")
      # Symbol keys also work (indifferent access)
      expect(result[:name]).to eq("Alice")
    end

    it "recursively stringifies nested hashes with indifferent access" do
      result = described_class.stringify_keys({ outer: { inner: "value" } })

      expect(result["outer"]).to be_a(described_class::IndifferentHash)
      expect(result["outer"]["inner"]).to eq("value")
      expect(result[:outer][:inner]).to eq("value")
    end

    it "stringifies hashes in arrays with indifferent access" do
      result = described_class.stringify_keys([{ a: 1 }, { b: 2 }])

      expect(result[0]).to be_a(described_class::IndifferentHash)
      expect(result[0][:a]).to eq(1)
      expect(result[1]["b"]).to eq(2)
    end

    it "handles deeply nested structures" do
      input = { l1: [{ l2: { l3: [{ l4: "value" }] } }] }
      result = described_class.stringify_keys(input)

      # All hash levels support indifferent access
      expect(result[:l1][0][:l2][:l3][0][:l4]).to eq("value")
      expect(result["l1"][0]["l2"]["l3"][0]["l4"]).to eq("value")
    end

    it "passes through non-hash/array values unchanged" do
      expect(described_class.stringify_keys("string")).to eq("string")
      expect(described_class.stringify_keys(123)).to eq(123)
      expect(described_class.stringify_keys(nil)).to be_nil
    end

    it "handles empty structures" do
      empty_hash = described_class.stringify_keys({})
      empty_array = described_class.stringify_keys([])

      expect(empty_hash).to be_a(described_class::IndifferentHash)
      expect(empty_hash).to be_empty
      expect(empty_array).to eq([])
    end

    context "with mixed key types" do
      it "converts all keys to strings" do
        result = described_class.stringify_keys({ :symbol => 1, "string" => 2 })

        expect(result.keys).to all(be_a(String))
        expect(result["symbol"]).to eq(1)
        expect(result["string"]).to eq(2)
      end
    end

    context "key? indifferent access" do
      it "finds keys with either syntax" do
        result = described_class.stringify_keys({ name: "Alice" })

        expect(result.key?("name")).to be true
        expect(result.key?(:name)).to be true
        expect(result.key?("missing")).to be false
        expect(result.key?(:missing)).to be false
      end
    end

    context "fetch indifferent access" do
      it "fetches with either syntax" do
        result = described_class.stringify_keys({ name: "Alice" })

        expect(result.fetch("name")).to eq("Alice")
        expect(result.fetch(:name)).to eq("Alice")
      end

      it "uses default for missing keys" do
        result = described_class.stringify_keys({ name: "Alice" })

        expect(result.fetch("missing", "default")).to eq("default")
        expect(result.fetch(:missing, "default")).to eq("default")
      end
    end
  end

  describe ".freeze" do
    it "returns primitives unchanged" do
      expect(described_class.freeze(42)).to eq(42)
      expect(described_class.freeze(3.14)).to eq(3.14)
      expect(described_class.freeze(:symbol)).to eq(:symbol)
      expect(described_class.freeze(nil)).to be_nil
      expect(described_class.freeze(true)).to be(true)
      expect(described_class.freeze(false)).to be(false)
    end

    it "freezes arrays and their contents" do
      result = described_class.freeze([1, "two", [3]])

      expect(result).to be_frozen
      expect(result[1]).to be_frozen
      expect(result[2]).to be_frozen
    end

    it "freezes hashes and their values" do
      result = described_class.freeze({ a: "value", b: { c: "nested" } })

      expect(result).to be_frozen
      expect(result[:a]).to be_frozen
      expect(result[:b]).to be_frozen
      expect(result[:b][:c]).to be_frozen
    end

    it "dups unfrozen strings before freezing" do
      original = +"mutable"
      result = described_class.freeze(original)

      expect(result).to be_frozen
      expect(original).not_to be_frozen
    end

    it "returns already frozen strings as-is" do
      frozen = "immutable".freeze
      result = described_class.freeze(frozen)

      expect(result).to be(frozen)
    end

    it "handles custom objects with freeze" do
      obj = Object.new
      result = described_class.freeze(obj)

      expect(result).to be_frozen
    end
  end

  describe ".dup" do
    it "returns primitives unchanged" do
      expect(described_class.dup(42)).to eq(42)
      expect(described_class.dup(3.14)).to eq(3.14)
      expect(described_class.dup(:symbol)).to eq(:symbol)
      expect(described_class.dup(nil)).to be_nil
      expect(described_class.dup(true)).to be(true)
      expect(described_class.dup(false)).to be(false)
    end

    it "creates independent string copies" do
      original = "hello"
      result = described_class.dup(original)

      result << " world"
      expect(original).to eq("hello")
    end

    it "creates independent array copies" do
      original = [1, 2, 3]
      result = described_class.dup(original)

      result << 4
      expect(original).to eq([1, 2, 3])
    end

    it "creates independent hash copies" do
      original = { a: 1 }
      result = described_class.dup(original)

      result[:b] = 2
      expect(original).to eq({ a: 1 })
    end

    it "deeply duplicates nested structures" do
      original = { outer: { inner: "value" } }
      result = described_class.dup(original)

      result[:outer][:inner] = "changed"
      expect(original[:outer][:inner]).to eq("value")
    end

    it "duplicates keys as well as values" do
      key = +"key"
      original = { key => "value" }
      result = described_class.dup(original)

      expect(result.keys.first).not_to be(key)
    end

    it "returns undupable objects as-is" do
      singleton = (class << Object.new; self; end)

      expect(described_class.dup(singleton)).to be(singleton)
    end

    it "duplicates frozen hashes into new mutable copies" do
      frozen = { a: 1 }.freeze
      result = described_class.dup(frozen)

      expect(result).to eq(frozen)
      expect(result).not_to be(frozen)
    end
  end

  describe ".safe_freeze" do
    it "freezes normal objects" do
      obj = "mutable"
      result = described_class.safe_freeze(obj)

      expect(result).to be_frozen
    end

    it "handles already frozen objects" do
      frozen = "frozen"
      result = described_class.safe_freeze(frozen)

      expect(result).to be(frozen)
    end
  end
end
