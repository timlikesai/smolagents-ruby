require "spec_helper"

RSpec.describe Smolagents::Builders::Base::Metadata do
  let(:test_builder_class) do
    Class.new do
      extend Smolagents::Builders::Base::Metadata
    end
  end

  describe ".register_method" do
    it "registers a method with description" do
      test_builder_class.register_method(:test_method, description: "Test description")

      expect(test_builder_class.registered_methods).to have_key(:test_method)
      expect(test_builder_class.registered_methods[:test_method][:description])
        .to eq("Test description")
    end

    it "registers with required flag" do
      test_builder_class.register_method(:model, description: "Model", required: true)

      expect(test_builder_class.registered_methods[:model][:required]).to be true
    end

    it "defaults required to false" do
      test_builder_class.register_method(:optional, description: "Optional")

      expect(test_builder_class.registered_methods[:optional][:required]).to be false
    end

    it "registers with validation block" do
      validator = ->(v) { v.is_a?(Integer) && v > 0 }
      test_builder_class.register_method(
        :positive_int,
        description: "Positive integer",
        validates: validator
      )

      expect(test_builder_class.registered_methods[:positive_int][:validates])
        .to eq(validator)
    end

    it "defaults validates to nil" do
      test_builder_class.register_method(:no_validation, description: "No validation")

      expect(test_builder_class.registered_methods[:no_validation][:validates]).to be_nil
    end

    it "registers with aliases" do
      test_builder_class.register_method(
        :original,
        description: "Original",
        aliases: %i[alias1 alias2]
      )

      expect(test_builder_class.registered_methods).to have_key(:alias1)
      expect(test_builder_class.registered_methods).to have_key(:alias2)
    end

    it "marks aliases with alias_of" do
      test_builder_class.register_method(
        :original,
        description: "Original",
        aliases: [:alias1]
      )

      expect(test_builder_class.registered_methods[:alias1][:alias_of]).to eq(:original)
    end

    it "preserves original method metadata on alias" do
      test_builder_class.register_method(
        :original,
        description: "Original desc",
        required: true,
        aliases: [:alias1]
      )

      alias_meta = test_builder_class.registered_methods[:alias1]
      expect(alias_meta[:description]).to eq("Original desc")
      expect(alias_meta[:required]).to be true
    end

    it "allows registering multiple methods" do
      test_builder_class.register_method(:method1, description: "First")
      test_builder_class.register_method(:method2, description: "Second")
      test_builder_class.register_method(:method3, description: "Third")

      expect(test_builder_class.registered_methods.size).to be >= 3
    end

    it "overwrites previous registration for same method name" do
      test_builder_class.register_method(:overwrite, description: "Old")
      test_builder_class.register_method(:overwrite, description: "New")

      expect(test_builder_class.registered_methods[:overwrite][:description]).to eq("New")
    end
  end

  describe ".registered_methods" do
    it "returns a hash" do
      expect(test_builder_class.registered_methods).to be_a(Hash)
    end

    it "is empty initially" do
      expect(test_builder_class.registered_methods).to be_empty
    end

    it "includes all registered methods" do
      test_builder_class.register_method(:method1, description: "First")
      test_builder_class.register_method(:method2, description: "Second")

      expect(test_builder_class.registered_methods).to include(:method1, :method2)
    end

    it "includes metadata for each method" do
      test_builder_class.register_method(:test, description: "Test", required: true)

      meta = test_builder_class.registered_methods[:test]
      expect(meta).to be_a(Hash)
      expect(meta).to include(:description, :required, :validates, :aliases)
    end

    it "persists across multiple calls" do
      test_builder_class.register_method(:persist, description: "Persist")

      result1 = test_builder_class.registered_methods
      result2 = test_builder_class.registered_methods

      expect(result1).to include(:persist)
      expect(result2).to include(:persist)
    end

    it "returns consistent metadata" do
      validator = ->(v) { v.is_a?(String) }
      test_builder_class.register_method(
        :consistent,
        description: "Consistent",
        validates: validator,
        required: true
      )

      meta1 = test_builder_class.registered_methods[:consistent]
      meta2 = test_builder_class.registered_methods[:consistent]

      expect(meta1).to eq(meta2)
    end
  end

  describe ".required_methods" do
    it "returns an array" do
      expect(test_builder_class.required_methods).to be_a(Array)
    end

    it "is empty when no methods registered" do
      expect(test_builder_class.required_methods).to be_empty
    end

    it "includes only required methods" do
      test_builder_class.register_method(:required1, description: "Req1", required: true)
      test_builder_class.register_method(:optional1, description: "Opt1", required: false)
      test_builder_class.register_method(:required2, description: "Req2", required: true)

      required = test_builder_class.required_methods

      expect(required).to include(:required1, :required2)
      expect(required).not_to include(:optional1)
    end

    it "excludes aliases" do
      test_builder_class.register_method(
        :original,
        description: "Original",
        required: true,
        aliases: [:alias1]
      )

      required = test_builder_class.required_methods

      expect(required).to include(:original)
      expect(required).not_to include(:alias1)
    end

    it "returns empty array when no required methods" do
      test_builder_class.register_method(:optional, description: "Optional", required: false)

      expect(test_builder_class.required_methods).to be_empty
    end

    it "returns all required method names" do
      test_builder_class.register_method(:model, description: "Model", required: true)
      test_builder_class.register_method(:tools, description: "Tools", required: false)
      test_builder_class.register_method(:max_steps, description: "Max Steps", required: true)

      required = test_builder_class.required_methods

      expect(required).to include(:model, :max_steps)
      expect(required).not_to include(:tools)
    end

    it "returns symbols" do
      test_builder_class.register_method(:test, description: "Test", required: true)

      required = test_builder_class.required_methods

      expect(required.all?(Symbol)).to be true
    end
  end

  describe "integration with validation" do
    it "stores validator for use in validation methods" do
      validator = ->(v) { v > 0 }
      test_builder_class.register_method(
        :positive,
        description: "Positive",
        validates: validator
      )

      meta = test_builder_class.registered_methods[:positive]
      expect(meta[:validates].call(5)).to be true
      expect(meta[:validates].call(-5)).to be false
    end

    it "works with complex validators" do
      validator = ->(v) { v.is_a?(String) && v.length > 3 }
      test_builder_class.register_method(
        :name,
        description: "Name",
        validates: validator
      )

      meta = test_builder_class.registered_methods[:name]
      expect(meta[:validates].call("John")).to be true
      expect(meta[:validates].call("Jo")).to be false
    end
  end

  describe "multiple classes" do
    let(:class1) do
      Class.new do
        extend Smolagents::Builders::Base::Metadata
      end
    end

    let(:class2) do
      Class.new do
        extend Smolagents::Builders::Base::Metadata
      end
    end

    it "maintains separate registrations per class" do
      class1.register_method(:method1, description: "Class 1 method")
      class2.register_method(:method2, description: "Class 2 method")

      expect(class1.registered_methods).to include(:method1)
      expect(class1.registered_methods).not_to include(:method2)
      expect(class2.registered_methods).to include(:method2)
      expect(class2.registered_methods).not_to include(:method1)
    end

    it "required_methods are also separate" do
      class1.register_method(:req1, description: "Required 1", required: true)
      class2.register_method(:opt1, description: "Optional 1", required: false)

      expect(class1.required_methods).to include(:req1)
      expect(class2.required_methods).to be_empty
    end
  end

  describe "edge cases" do
    it "accepts empty description" do
      test_builder_class.register_method(:empty, description: "")

      expect(test_builder_class.registered_methods[:empty][:description]).to eq("")
    end

    it "accepts empty aliases array" do
      test_builder_class.register_method(:no_aliases, description: "No aliases", aliases: [])

      expect(test_builder_class.registered_methods[:no_aliases][:aliases]).to eq([])
    end

    it "accepts very long description" do
      long_desc = "A" * 1000
      test_builder_class.register_method(:long, description: long_desc)

      expect(test_builder_class.registered_methods[:long][:description]).to eq(long_desc)
    end

    it "supports symbols as method names" do
      test_builder_class.register_method(:symbol_name, description: "Symbol")

      expect(test_builder_class.registered_methods).to have_key(:symbol_name)
    end

    it "validator can be false" do
      validator = ->(v) { false }
      test_builder_class.register_method(
        :never_valid,
        description: "Never valid",
        validates: validator
      )

      meta = test_builder_class.registered_methods[:never_valid]
      expect(meta[:validates].call(nil)).to be false
    end
  end
end
