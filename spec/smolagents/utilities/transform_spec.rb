RSpec.describe Smolagents::Utilities::Transform do
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
      original = "mutable"
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
      key = "key"
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
      frozen = "frozen".freeze
      result = described_class.safe_freeze(frozen)

      expect(result).to be(frozen)
    end
  end
end
