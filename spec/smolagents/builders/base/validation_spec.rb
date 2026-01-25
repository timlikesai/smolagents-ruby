require "spec_helper"

RSpec.describe Smolagents::Builders::Base::Validation do
  let(:test_builder_class) do
    Class.new(Data.define(:configuration)) do
      extend Smolagents::Builders::Base::Metadata
      include Smolagents::Builders::Base::Validation

      def self.create
        new(configuration: {})
      end
    end
  end

  describe "#validate!" do
    context "with valid value" do
      it "does nothing when validation passes" do
        test_builder_class.register_method(
          :positive,
          description: "Positive",
          validates: ->(v) { v > 0 }
        )

        builder = test_builder_class.create
        expect { builder.validate!(:positive, 5) }.not_to raise_error
      end

      it "does nothing when no validator registered" do
        test_builder_class.register_method(:no_validator, description: "No validator")

        builder = test_builder_class.create
        expect { builder.validate!(:no_validator, "anything") }.not_to raise_error
      end

      it "does nothing for unregistered method" do
        builder = test_builder_class.create
        expect { builder.validate!(:unknown, 42) }.not_to raise_error
      end
    end

    context "with invalid value" do
      it "raises ArgumentError when validation fails" do
        test_builder_class.register_method(
          :positive,
          description: "Must be positive",
          validates: ->(v) { v > 0 }
        )

        builder = test_builder_class.create
        expect { builder.validate!(:positive, -5) }
          .to raise_error(ArgumentError, /Invalid value/)
      end

      it "includes method name in error message" do
        test_builder_class.register_method(
          :test,
          description: "Test description",
          validates: ->(v) { false }
        )

        builder = test_builder_class.create
        expect { builder.validate!(:test, 42) }
          .to raise_error(ArgumentError, /test/)
      end

      it "includes description in error message" do
        test_builder_class.register_method(
          :special,
          description: "This is special",
          validates: ->(v) { false }
        )

        builder = test_builder_class.create
        expect { builder.validate!(:special, 42) }
          .to raise_error(ArgumentError, /This is special/)
      end

      it "includes value in error message" do
        test_builder_class.register_method(
          :test,
          description: "Test",
          validates: ->(v) { false }
        )

        builder = test_builder_class.create
        expect { builder.validate!(:test, 999) }
          .to raise_error(ArgumentError, /999/)
      end
    end

    context "complex validators" do
      it "validates type" do
        test_builder_class.register_method(
          :string_only,
          description: "Must be string",
          validates: ->(v) { v.is_a?(String) }
        )

        builder = test_builder_class.create
        expect { builder.validate!(:string_only, "valid") }.not_to raise_error
        expect { builder.validate!(:string_only, 42) }
          .to raise_error(ArgumentError)
      end

      it "validates range" do
        test_builder_class.register_method(
          :in_range,
          description: "Must be 0-10",
          validates: ->(v) { v.is_a?(Integer) && (0..10).cover?(v) }
        )

        builder = test_builder_class.create
        expect { builder.validate!(:in_range, 5) }.not_to raise_error
        expect { builder.validate!(:in_range, 15) }
          .to raise_error(ArgumentError)
      end

      it "validates collection members" do
        test_builder_class.register_method(
          :all_symbols,
          description: "All must be symbols",
          validates: ->(v) { v.is_a?(Array) && v.all?(Symbol) }
        )

        builder = test_builder_class.create
        expect { builder.validate!(:all_symbols, %i[a b c]) }.not_to raise_error
        expect { builder.validate!(:all_symbols, [:a, "b"]) }
          .to raise_error(ArgumentError)
      end
    end

    context "multiple validations" do
      it "validates different methods independently" do
        test_builder_class.register_method(
          :int_val,
          description: "Integer",
          validates: ->(v) { v.is_a?(Integer) }
        )
        test_builder_class.register_method(
          :str_val,
          description: "String",
          validates: ->(v) { v.is_a?(String) }
        )

        builder = test_builder_class.create
        expect { builder.validate!(:int_val, 42) }.not_to raise_error
        expect { builder.validate!(:str_val, "test") }.not_to raise_error
        expect { builder.validate!(:int_val, "test") }.to raise_error(ArgumentError)
        expect { builder.validate!(:str_val, 42) }.to raise_error(ArgumentError)
      end
    end
  end

  describe "#validate_required!" do
    context "with all required methods called" do
      it "does nothing when all required methods are set" do
        test_builder_class.register_method(:model, description: "Model", required: true)
        test_builder_class.register_method(:tools, description: "Tools", required: true)

        builder = test_builder_class.new(configuration: { model: "gpt-4", tools: [:search] })
        expect { builder.validate_required! }.not_to raise_error
      end

      it "does nothing when configuration has the key even if nil" do
        test_builder_class.register_method(:optional, description: "Optional", required: true)

        builder = test_builder_class.new(configuration: { optional: nil })
        expect { builder.validate_required! }.not_to raise_error
      end
    end

    context "with missing required methods" do
      it "raises ArgumentError when required method missing" do
        test_builder_class.register_method(:model, description: "Model", required: true)

        builder = test_builder_class.create
        expect { builder.validate_required! }
          .to raise_error(ArgumentError, /Missing required/)
      end

      it "includes missing method names in error" do
        test_builder_class.register_method(:model, description: "Model", required: true)
        test_builder_class.register_method(:tools, description: "Tools", required: true)

        builder = test_builder_class.create
        expect { builder.validate_required! }
          .to raise_error(ArgumentError, /model.*tools/)
      end

      it "does not include optional methods in error" do
        test_builder_class.register_method(:model, description: "Model", required: true)
        test_builder_class.register_method(:optional, description: "Optional", required: false)

        builder = test_builder_class.create
        expect { builder.validate_required! }
          .to raise_error(ArgumentError)

        error_message = begin
          builder.validate_required!
        rescue ArgumentError => e
          e.message
        end

        expect(error_message).to include("model")
        expect(error_message).not_to include("optional")
      end

      it "suggests using help" do
        test_builder_class.register_method(:model, description: "Model", required: true)

        builder = test_builder_class.create
        expect { builder.validate_required! }
          .to raise_error(ArgumentError, /help/)
      end
    end

    context "with multiple missing required methods" do
      it "lists all missing methods" do
        test_builder_class.register_method(:model, description: "Model", required: true)
        test_builder_class.register_method(:tools, description: "Tools", required: true)
        test_builder_class.register_method(:max_steps, description: "Max Steps", required: true)

        builder = test_builder_class.create
        expect { builder.validate_required! }
          .to raise_error(ArgumentError, /model.*tools.*max_steps/)
      end

      it "includes only truly missing methods" do
        test_builder_class.register_method(:model, description: "Model", required: true)
        test_builder_class.register_method(:tools, description: "Tools", required: true)

        builder = test_builder_class.new(configuration: { model: "gpt-4" })
        expect { builder.validate_required! }
          .to raise_error(ArgumentError)

        error_message = begin
          builder.validate_required!
        rescue ArgumentError => e
          e.message
        end

        expect(error_message).to include("tools")
        expect(error_message).not_to include("model")
      end
    end

    context "aliases" do
      it "ignores aliases when checking required methods" do
        test_builder_class.register_method(
          :original,
          description: "Original",
          required: true,
          aliases: [:alias1]
        )

        builder = test_builder_class.create
        expect { builder.validate_required! }
          .to raise_error(ArgumentError, /original/)
      end

      it "does not complain about alias variants" do
        test_builder_class.register_method(
          :original,
          description: "Original",
          required: true,
          aliases: [:alias1]
        )

        builder = test_builder_class.new(configuration: { original: "value" })
        expect { builder.validate_required! }.not_to raise_error
      end
    end

    context "no required methods" do
      it "does nothing when no required methods" do
        test_builder_class.register_method(:optional, description: "Optional", required: false)

        builder = test_builder_class.create
        expect { builder.validate_required! }.not_to raise_error
      end

      it "does nothing for empty configuration" do
        builder = test_builder_class.create
        expect { builder.validate_required! }.not_to raise_error
      end
    end

    context "integration" do
      it "works with configuration merging" do
        test_builder_class.register_method(:model, description: "Model", required: true)

        builder = test_builder_class.create
        partial_config = test_builder_class.new(configuration: { model: "gpt-4" })

        expect { builder.validate_required! }.to raise_error(ArgumentError)
        expect { partial_config.validate_required! }.not_to raise_error
      end
    end
  end
end
