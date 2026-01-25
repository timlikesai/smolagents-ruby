require "spec_helper"

RSpec.describe Smolagents::Types::Callbacks::TypeResolver do
  describe ".resolve" do
    context "with Class type" do
      it "returns the class as-is" do
        expect(described_class.resolve(String)).to eq(String)
        expect(described_class.resolve(Integer)).to eq(Integer)
        expect(described_class.resolve(NilClass)).to eq(NilClass)
      end
    end

    context "with String type (deferred resolution)" do
      it "resolves to actual class" do
        resolved = described_class.resolve("Types::TokenUsage")
        expect(resolved).to eq(Smolagents::Types::TokenUsage)
      end

      it "resolves nested types" do
        resolved = described_class.resolve("Types::ActionStep")
        expect(resolved).to eq(Smolagents::Types::ActionStep)
      end

      it "raises NameError for invalid type strings" do
        expect { described_class.resolve("Types::NonExistent") }
          .to raise_error(NameError)
      end
    end

    context "with Array type (union)" do
      it "resolves each type in array" do
        resolved = described_class.resolve([Symbol, String])
        expect(resolved).to eq([Symbol, String])
      end

      it "resolves deferred types in array" do
        resolved = described_class.resolve(["Types::TokenUsage", NilClass])
        expect(resolved).to eq([Smolagents::Types::TokenUsage, NilClass])
      end

      it "handles mixed direct and deferred types" do
        resolved = described_class.resolve([String, "Types::TokenUsage", Integer])
        expect(resolved).to eq([String, Smolagents::Types::TokenUsage, Integer])
      end
    end

    context "with other values" do
      it "returns value as-is for non-class, non-string, non-array" do
        expect(described_class.resolve(nil)).to be_nil
        expect(described_class.resolve(42)).to eq(42)
      end
    end
  end

  describe ".valid?" do
    context "with single Class type" do
      it "returns true when value is instance of type" do
        expect(described_class.valid?("hello", String)).to be true
        expect(described_class.valid?(42, Integer)).to be true
        expect(described_class.valid?(nil, NilClass)).to be true
      end

      it "returns false when value is not instance of type" do
        expect(described_class.valid?("hello", Integer)).to be false
        expect(described_class.valid?(42, String)).to be false
      end

      it "handles inheritance" do
        error = StandardError.new("test")
        expect(described_class.valid?(error, Exception)).to be true
        expect(described_class.valid?(error, StandardError)).to be true
      end
    end

    context "with Array type (union)" do
      it "returns true when value matches any type" do
        expect(described_class.valid?(:symbol, [Symbol, String])).to be true
        expect(described_class.valid?("string", [Symbol, String])).to be true
      end

      it "returns false when value matches no type" do
        expect(described_class.valid?(42, [Symbol, String])).to be false
      end

      it "handles NilClass in union" do
        expect(described_class.valid?(nil, [String, NilClass])).to be true
        expect(described_class.valid?("hello", [String, NilClass])).to be true
      end
    end

    context "with non-class expected type" do
      it "returns false" do
        expect(described_class.valid?("hello", "String")).to be false
        expect(described_class.valid?(42, nil)).to be false
      end
    end

    context "with resolved deferred types" do
      it "works after resolution" do
        resolved = described_class.resolve("Types::TokenUsage")
        usage = Smolagents::Types::TokenUsage.new(input_tokens: 10, output_tokens: 5)
        expect(described_class.valid?(usage, resolved)).to be true
      end
    end
  end

  describe "integration with CallbackSignature" do
    let(:signature) do
      Smolagents::Types::Callbacks::CallbackSignature.new(
        required_args: [:usage],
        optional_args: [:name],
        arg_types: {
          usage: "Types::TokenUsage",
          name: [Symbol, String]
        }
      )
    end

    it "validates deferred types correctly" do
      usage = Smolagents::Types::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      expect { signature.validate_args!(:test, usage:) }.not_to raise_error
    end

    it "validates union types correctly" do
      usage = Smolagents::Types::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      expect { signature.validate_args!(:test, usage:, name: :symbol) }.not_to raise_error
      expect { signature.validate_args!(:test, usage:, name: "string") }.not_to raise_error
    end

    it "rejects invalid types" do
      usage = Smolagents::Types::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      expect { signature.validate_args!(:test, usage:, name: 123) }
        .to raise_error(Smolagents::Types::Callbacks::InvalidArgumentError)
    end
  end

  describe "typical usage patterns" do
    it "resolves common callback types" do
      expect(described_class.resolve(Integer)).to eq(Integer)
      expect(described_class.resolve([Symbol, String])).to eq([Symbol, String])
      expect(described_class.resolve("Types::TokenUsage")).to eq(Smolagents::Types::TokenUsage)
    end

    it "validates common callback argument patterns" do
      expect(described_class.valid?(1, Integer)).to be true
      expect(described_class.valid?(:step, [Symbol, String])).to be true
      expect(described_class.valid?("step", [Symbol, String])).to be true

      usage = Smolagents::Types::TokenUsage.new(input_tokens: 10, output_tokens: 5)
      expect(described_class.valid?(usage, Smolagents::Types::TokenUsage)).to be true
    end
  end
end
