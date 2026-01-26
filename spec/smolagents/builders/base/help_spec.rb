require "spec_helper"

RSpec.describe Smolagents::Builders::Base::Help do
  let(:test_builder_class) do
    Class.new(Data.define(:configuration)) do
      extend Smolagents::Builders::Base::Metadata
      include Smolagents::Builders::Base::Help

      def self.create
        new(configuration: {})
      end
    end
  end

  describe "#help" do
    context "basic output" do
      it "returns a string" do
        builder = test_builder_class.create
        expect(builder.help).to be_a(String)
      end

      it "includes class name or class description" do
        builder = test_builder_class.create
        help_text = builder.help

        # Should include either the full class name or a reference to the builder
        expect(help_text).to include("Available Methods")
      end

      it "includes 'Available Methods' header" do
        builder = test_builder_class.create
        help_text = builder.help

        expect(help_text).to include("Available Methods")
      end

      it "has proper formatting with separator" do
        builder = test_builder_class.create
        help_text = builder.help

        expect(help_text).to include("=" * 60)
      end
    end

    context "required methods section" do
      it "shows required methods when present" do
        test_builder_class.register_method(:model, description: "Model", required: true)

        builder = test_builder_class.create
        help_text = builder.help

        expect(help_text).to include("Required")
        expect(help_text).to include("model")
      end

      it "omits required section when no required methods" do
        test_builder_class.register_method(:optional, description: "Optional", required: false)

        builder = test_builder_class.create
        help_text = builder.help

        # Should not have "Required:" section
        expect(help_text).not_to include("Required:")
      end

      it "formats required method names with dot prefix" do
        test_builder_class.register_method(:model, description: "Model", required: true)

        builder = test_builder_class.create
        help_text = builder.help

        expect(help_text).to include(".model")
      end

      it "includes descriptions for required methods" do
        test_builder_class.register_method(:model, description: "Set the LLM model", required: true)

        builder = test_builder_class.create
        help_text = builder.help

        expect(help_text).to include("Set the LLM model")
      end
    end

    context "optional methods section" do
      it "shows optional methods when present" do
        test_builder_class.register_method(:tools, description: "Tools", required: false)

        builder = test_builder_class.create
        help_text = builder.help

        expect(help_text).to include("Optional")
        expect(help_text).to include("tools")
      end

      it "omits optional section when no optional methods" do
        test_builder_class.register_method(:model, description: "Model", required: true)

        builder = test_builder_class.create
        help_text = builder.help

        expect(help_text).not_to include("Optional:")
      end

      it "formats optional method names with dot prefix" do
        test_builder_class.register_method(:tools, description: "Tools", required: false)

        builder = test_builder_class.create
        help_text = builder.help

        expect(help_text).to include(".tools")
      end

      it "includes descriptions for optional methods" do
        test_builder_class.register_method(:tools, description: "Add available tools", required: false)

        builder = test_builder_class.create
        help_text = builder.help

        expect(help_text).to include("Add available tools")
      end
    end

    context "aliases" do
      it "shows aliases in parentheses" do
        test_builder_class.register_method(
          :original,
          description: "Original",
          aliases: %i[alias1 alias2]
        )

        builder = test_builder_class.create
        help_text = builder.help

        expect(help_text).to include("aliases:")
        expect(help_text).to include("alias1")
        expect(help_text).to include("alias2")
      end

      it "does not show aliases section when no aliases" do
        test_builder_class.register_method(:no_alias, description: "No alias")

        builder = test_builder_class.create
        help_text = builder.help

        expect(help_text).not_to include("(aliases:")
      end

      it "only shows aliases for original methods, not vice versa" do
        test_builder_class.register_method(
          :original,
          description: "Original",
          aliases: [:alias1]
        )

        builder = test_builder_class.create
        help_text = builder.help

        # Should show original with its alias
        expect(help_text).to include(".original")
        expect(help_text).to include("aliases:")
        # Should not show alias as separate entry
        lines = help_text.lines
        lines.find { |l| l.include?(".original") }
        alias_line = lines.find { |l| l.include?(".alias1") && !l.include?("aliases:") }

        expect(alias_line).to be_nil
      end
    end

    context "current configuration section" do
      it "includes 'Current Configuration' section" do
        builder = test_builder_class.create
        help_text = builder.help

        expect(help_text).to include("Current Configuration")
      end

      it "shows builder inspect in configuration" do
        builder = test_builder_class.create
        help_text = builder.help

        expect(help_text).to include(builder.inspect)
      end
    end

    context "pattern matching section" do
      it "includes pattern matching example" do
        builder = test_builder_class.create
        help_text = builder.help

        expect(help_text).to include("Pattern Matching")
        expect(help_text).to include("case builder")
        expect(help_text).to include("in")
        expect(help_text).to include("Match and destructure")
      end

      it "includes Data.define attributes in example" do
        builder = test_builder_class.create
        help_text = builder.help

        # Should show pattern for Data class
        expect(help_text).to match(/in.*\[.*\]/)
      end
    end

    context "build section" do
      it "includes build instructions" do
        builder = test_builder_class.create
        help_text = builder.help

        expect(help_text).to include("Build")
        expect(help_text).to include(".build")
      end
    end

    context "mixed required and optional" do
      it "shows both sections when both types present" do
        test_builder_class.register_method(:model, description: "Model", required: true)
        test_builder_class.register_method(:tools, description: "Tools", required: false)

        builder = test_builder_class.create
        help_text = builder.help

        expect(help_text).to include("Required:")
        expect(help_text).to include("Optional:")
        expect(help_text).to include("model")
        expect(help_text).to include("tools")
      end
    end

    context "formatting details" do
      it "indents method descriptions" do
        test_builder_class.register_method(:test, description: "Test method")

        builder = test_builder_class.create
        help_text = builder.help

        # Description should be indented more than method name
        expect(help_text).to match(/\n  \.test\n    /)
      end

      it "uses consistent formatting" do
        test_builder_class.register_method(:method1, description: "First", required: true)
        test_builder_class.register_method(:method2, description: "Second", required: true)

        builder = test_builder_class.create
        help_text = builder.help

        # Both methods should have similar structure
        lines = help_text.lines
        method_lines = lines.grep(/^\s+\./)
        expect(method_lines.size).to be >= 2
      end

      it "formats help output readably" do
        test_builder_class.register_method(:model, description: "Model", required: true)
        test_builder_class.register_method(:tools, description: "Tools", required: false)

        builder = test_builder_class.create
        help_text = builder.help

        # Should be readable
        expect(help_text.length).to be > 0
        expect(help_text).to include("Available Methods")
      end
    end

    context "edge cases" do
      it "handles methods with special characters in description", max_time: 0.15 do
        test_builder_class.register_method(
          :special,
          description: "Test with 'quotes' and \"double quotes\""
        )

        builder = test_builder_class.create
        help_text = builder.help

        expect(help_text).to include("'quotes'")
        expect(help_text).to include('"double quotes"')
      end

      it "handles very long descriptions" do
        long_desc = "A" * 200
        test_builder_class.register_method(:long, description: long_desc)

        builder = test_builder_class.create
        help_text = builder.help

        expect(help_text).to include(long_desc)
      end

      it "handles empty configuration" do
        builder = test_builder_class.new(configuration: {})
        help_text = builder.help

        expect(help_text).to be_a(String)
        expect(help_text.length).to be > 0
      end
    end

    context "repl-friendly" do
      it "produces readable help text" do
        test_builder_class.register_method(:model, description: "Set the model", required: true)
        test_builder_class.register_method(:tools, description: "Add tools", required: false)

        builder = test_builder_class.create
        help_text = builder.help

        # Should be printable without issues - no error expected
        expect(help_text).to be_a(String)
        expect(help_text).not_to include("\x00") # No null bytes
      end

      it "starts with newline for repl display" do
        builder = test_builder_class.create
        help_text = builder.help

        expect(help_text).to start_with("\n")
      end

      it "ends with newline" do
        builder = test_builder_class.create
        help_text = builder.help

        expect(help_text).to end_with("\n")
      end
    end
  end
end
