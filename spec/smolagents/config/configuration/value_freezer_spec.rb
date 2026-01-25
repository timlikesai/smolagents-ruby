require "spec_helper"

RSpec.describe Smolagents::Config::Configuration::ValueFreezer do
  # Create a test class that includes the module
  let(:freezer_class) do
    Class.new do
      include Smolagents::Config::Configuration::ValueFreezer

      def freeze_public(value)
        freeze_value(value)
      end
    end
  end

  let(:freezer) { freezer_class.new }

  describe "#freeze_value" do
    context "with primitives" do
      it "returns nil unchanged" do
        expect(freezer.freeze_public(nil)).to be_nil
      end

      it "returns symbols unchanged" do
        expect(freezer.freeze_public(:test)).to eq(:test)
      end

      it "returns integers unchanged" do
        expect(freezer.freeze_public(42)).to eq(42)
      end

      it "returns floats unchanged" do
        expect(freezer.freeze_public(3.14)).to eq(3.14)
      end

      it "returns true unchanged" do
        expect(freezer.freeze_public(true)).to be true
      end

      it "returns false unchanged" do
        expect(freezer.freeze_public(false)).to be false
      end
    end

    context "with strings" do
      it "returns frozen strings unchanged" do
        frozen_str = "frozen".freeze
        result = freezer.freeze_public(frozen_str)

        expect(result).to be(frozen_str)
      end

      it "dups and freezes unfrozen strings" do
        str = +"mutable"
        result = freezer.freeze_public(str)

        expect(result).to be_frozen
        expect(result).to eq(str)
        expect(result).not_to be(str)
      end
    end

    context "with arrays" do
      it "freezes the array" do
        arr = [1, 2, 3]
        result = freezer.freeze_public(arr)

        expect(result).to be_frozen
      end

      it "recursively freezes nested values" do
        arr = ["one", ["two"]]
        result = freezer.freeze_public(arr)

        expect(result.first).to be_frozen
        expect(result.last).to be_frozen
        expect(result.last.first).to be_frozen
      end
    end

    context "with hashes" do
      it "freezes the hash" do
        hash = { a: 1, b: 2 }
        result = freezer.freeze_public(hash)

        expect(result).to be_frozen
      end

      it "recursively freezes nested values" do
        hash = { key: "value", nested: { inner: "deep" } }
        result = freezer.freeze_public(hash)

        expect(result[:key]).to be_frozen
        expect(result[:nested]).to be_frozen
        expect(result[:nested][:inner]).to be_frozen
      end
    end

    context "with other objects" do
      it "returns logger-like objects unchanged" do
        logger = Logger.new($stdout)
        result = freezer.freeze_public(logger)

        expect(result).to be(logger)
      end
    end
  end
end
