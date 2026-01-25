require "spec_helper"

RSpec.describe Smolagents::Persistence::Serialization do
  describe "PRIMITIVE_TYPES" do
    it "includes JSON-serializable types" do
      expect(described_class::PRIMITIVE_TYPES).to include(
        NilClass, TrueClass, FalseClass, Numeric, String, Symbol
      )
    end
  end

  describe ".serializable?" do
    it "returns true for nil" do
      expect(described_class.serializable?(nil)).to be true
    end

    it "returns true for booleans" do
      expect(described_class.serializable?(true)).to be true
      expect(described_class.serializable?(false)).to be true
    end

    it "returns true for numbers" do
      expect(described_class.serializable?(42)).to be true
      expect(described_class.serializable?(3.14)).to be true
    end

    it "returns true for strings" do
      expect(described_class.serializable?("hello")).to be true
    end

    it "returns true for symbols" do
      expect(described_class.serializable?(:hello)).to be true
    end

    it "returns true for arrays of primitives" do
      expect(described_class.serializable?([1, "two", :three])).to be true
    end

    it "returns true for hashes with primitive keys and values" do
      expect(described_class.serializable?({ a: 1, b: "two" })).to be true
    end

    it "returns true for nested serializable structures" do
      data = { users: [{ name: "Alice", age: 30 }, { name: "Bob", age: 25 }] }

      expect(described_class.serializable?(data)).to be true
    end

    it "returns false for objects" do
      expect(described_class.serializable?(Object.new)).to be false
    end

    it "returns false for arrays containing non-serializable values" do
      expect(described_class.serializable?([1, Object.new])).to be false
    end

    it "returns false for hashes with non-serializable values" do
      expect(described_class.serializable?({ a: Object.new })).to be false
    end

    it "returns false for hashes with non-serializable keys" do
      expect(described_class.serializable?({ Object.new => 1 })).to be false
    end
  end

  describe ".deep_symbolize_keys" do
    it "symbolizes top-level keys" do
      result = described_class.deep_symbolize_keys({ "a" => 1, "b" => 2 })

      expect(result).to eq({ a: 1, b: 2 })
    end

    it "symbolizes nested hash keys" do
      result = described_class.deep_symbolize_keys({
                                                     "outer" => { "inner" => "value" }
                                                   })

      expect(result).to eq({ outer: { inner: "value" } })
    end

    it "symbolizes keys in arrays of hashes" do
      result = described_class.deep_symbolize_keys([{ "a" => 1 }, { "b" => 2 }])

      expect(result).to eq([{ a: 1 }, { b: 2 }])
    end

    it "leaves non-hash values unchanged" do
      result = described_class.deep_symbolize_keys("string")

      expect(result).to eq("string")
    end
  end

  describe ".symbolize_keys" do
    it "converts string keys to symbols" do
      result = described_class.symbolize_keys({ "a" => 1, "b" => 2 })

      expect(result).to eq({ a: 1, b: 2 })
    end

    it "does not recursively symbolize" do
      result = described_class.symbolize_keys({ "outer" => { "inner" => 1 } })

      expect(result[:outer]).to eq({ "inner" => 1 })
    end
  end

  describe ".ivar_to_key" do
    it "removes @ prefix from instance variable names" do
      expect(described_class.ivar_to_key(:@temperature)).to eq(:temperature)
      expect(described_class.ivar_to_key(:@max_tokens)).to eq(:max_tokens)
    end

    it "returns symbol without @ unchanged" do
      expect(described_class.ivar_to_key(:temperature)).to eq(:temperature)
    end
  end

  describe ".extract_ivars" do
    let(:test_object) do
      obj = Object.new
      obj.instance_variable_set(:@temperature, 0.7)
      obj.instance_variable_set(:@max_tokens, 1000)
      obj.instance_variable_set(:@api_key, "secret")
      obj.instance_variable_set(:@client, Object.new)
      obj
    end

    it "extracts serializable instance variables" do
      result = described_class.extract_ivars(test_object)

      expect(result[:temperature]).to eq(0.7)
      expect(result[:max_tokens]).to eq(1000)
    end

    it "excludes specified variables" do
      result = described_class.extract_ivars(test_object, exclude: [:api_key])

      expect(result).not_to have_key(:api_key)
      expect(result[:temperature]).to eq(0.7)
    end

    it "excludes non-serializable values" do
      result = described_class.extract_ivars(test_object)

      expect(result).not_to have_key(:client)
    end

    it "converts instance variable names to keys" do
      result = described_class.extract_ivars(test_object)

      expect(result.keys).to all(be_a(Symbol))
      expect(result.keys).not_to include(:@temperature)
      expect(result.keys).to include(:temperature)
    end
  end
end
