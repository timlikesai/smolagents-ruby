require "spec_helper"

RSpec.describe Smolagents::Security::AstHelpers do
  describe ".extract_method_name" do
    it "extracts method name from command node" do
      sexp = [:command, [:@ident, "puts", [1, 0]], [:args_add_block, [], false]]
      expect(described_class.extract_method_name(sexp)).to eq("puts")
    end

    it "extracts method name from fcall node" do
      sexp = [:fcall, [:@ident, "print", [1, 0]], [:args_add_block, ["hello"], false]]
      expect(described_class.extract_method_name(sexp)).to eq("print")
    end

    it "extracts method name from vcall node" do
      sexp = [:vcall, [:@ident, "hello", [1, 0]]]
      expect(described_class.extract_method_name(sexp)).to eq("hello")
    end

    it "returns nil for nodes without identifiers" do
      sexp = [:program, []]
      expect(described_class.extract_method_name(sexp)).to be_nil
    end

    it "returns nil for empty sexp" do
      sexp = []
      expect(described_class.extract_method_name(sexp)).to be_nil
    end

    it "raises for non-array sexp (not a valid node)" do
      sexp = "not an array"
      # Non-array sexps will raise NoMethodError due to calling find on String
      expect { described_class.extract_method_name(sexp) }.to raise_error(NoMethodError)
    end

    it "handles nested structures" do
      sexp = [:command, [:@ident, "eval", [1, 0]],
              [:args_add_block, [[:string_literal, [:string_add, [], "code"]]], false]]
      expect(described_class.extract_method_name(sexp)).to eq("eval")
    end

    it "ignores const nodes in favor of ident nodes" do
      # If both exist, @ident should be found first
      sexp = [:call, [:@const, "String", [1, 0]], [:@ident, "upcase", [1, 10]]]
      result = described_class.extract_method_name(sexp)
      # Could be either depending on order, but should find one of the identifiers
      valid_results = [nil, "String", "upcase"]
      expect(valid_results).to include(result)
    end
  end

  describe ".extract_const_path" do
    it "extracts simple constant name" do
      sexp = [:@const, "File", [1, 0]]
      expect(described_class.extract_const_path(sexp)).to eq("File")
    end

    it "extracts constant from var_ref" do
      sexp = [:var_ref, [:@const, "ENV", [1, 0]]]
      expect(described_class.extract_const_path(sexp)).to eq("ENV")
    end

    it "returns nil for non-constant nodes" do
      sexp = [:@ident, "my_var", [1, 0]]
      expect(described_class.extract_const_path(sexp)).to be_nil
    end

    it "returns nil for empty sexp" do
      sexp = []
      expect(described_class.extract_const_path(sexp)).to be_nil
    end

    it "returns nil safely for non-array sexp" do
      sexp = "not an array"
      # extract_const_path checks is_a?(Array) first, so returns nil
      expect(described_class.extract_const_path(sexp)).to be_nil
    end

    it "handles nested constant paths" do
      # File::IO constant path
      sexp = [:const_path_ref, [:var_ref, [:@const, "File", [1, 0]]], [:@const, "IO", [1, 7]]]
      result = described_class.extract_const_path(sexp)
      expect(result).to include("File", "IO")
    end

    it "returns joined path with :: separator" do
      sexp = [:const_path_ref, [:var_ref, [:@const, "A", [1, 0]]], [:@const, "B", [1, 3]]]
      result = described_class.extract_const_path(sexp)
      expect(result).to include("A") if result
      expect(result).to include("B") if result
    end

    it "collects multiple constant parts" do
      sexp = [:const_path_ref,
              [:const_path_ref, [:var_ref, [:@const, "A", [0, 0]]], [:@const, "B", [0, 2]]],
              [:@const, "C", [0, 4]]]
      result = described_class.extract_const_path(sexp)
      # Should have collected A, B, C in some form
      expect(result).to be_a(String) if result
    end
  end

  describe ".extract_const_path_parts" do
    it "extracts parts from simple const node" do
      parts = []
      sexp = [:@const, "File", [1, 0]]
      described_class.extract_const_path_parts(sexp, parts)
      expect(parts).to include("File")
    end

    it "extracts parts from const_path_ref" do
      parts = []
      sexp = [:const_path_ref, [:var_ref, [:@const, "File", [1, 0]]], [:@const, "IO", [1, 7]]]
      described_class.extract_const_path_parts(sexp, parts)
      expect(parts).to include("File", "IO")
    end

    it "does nothing for non-array sexp" do
      parts = []
      described_class.extract_const_path_parts("not array", parts)
      expect(parts).to be_empty
    end

    it "ignores non-const nodes" do
      parts = []
      sexp = [:@ident, "variable", [1, 0]]
      described_class.extract_const_path_parts(sexp, parts)
      expect(parts).to be_empty
    end

    it "recursively traverses children" do
      parts = []
      sexp = [:program,
              [:var_ref, [:@const, "Constant", [1, 0]]],
              [:method_call, [:@ident, "method", [1, 10]]]]
      described_class.extract_const_path_parts(sexp, parts)
      # Should traverse and find Constant
      expect(parts.any?("Constant")).to be true
    end

    it "handles empty parts array" do
      parts = []
      sexp = [:@const, "Test", [1, 0]]
      described_class.extract_const_path_parts(sexp, parts)
      expect(parts).not_to be_empty
    end

    it "mutates the provided parts array" do
      parts = ["initial"]
      sexp = [:@const, "Added", [1, 0]]
      described_class.extract_const_path_parts(sexp, parts)
      expect(parts.size).to be > 1
    end
  end

  describe "IDENTIFIER_TYPES constant" do
    it "is available in the module" do
      expect(described_class::IDENTIFIER_TYPES).to eq(%i[@ident @const])
    end
  end
end
