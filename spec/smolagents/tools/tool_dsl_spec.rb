# frozen_string_literal: true

RSpec.describe Smolagents::Tools do
  describe ".define_tool" do
    it "creates a tool from a block" do
      tool = described_class.define_tool(
        :my_tool,
        description: "Test tool",
        inputs: { "x" => { "type" => "integer", "description" => "A number" } },
        output_type: "integer"
      ) do |x:|
        x * 2
      end

      expect(tool).to be_a(Smolagents::Tool)
      expect(tool.name).to eq("my_tool")
      expect(tool.description).to eq("Test tool")
    end

    it "executes the block when tool is called" do
      tool = described_class.define_tool(
        :doubler,
        description: "Doubles a number",
        inputs: { "n" => { "type" => "integer", "description" => "Number to double" } },
        output_type: "integer"
      ) do |n:|
        n * 2
      end

      result = tool.call(n: 5)
      expect(result).to eq(10)
    end

    it "raises error if no block given" do
      expect do
        described_class.define_tool(
          :bad_tool,
          description: "Bad",
          inputs: {},
          output_type: "any"
        )
      end.to raise_error(ArgumentError, /Block required/)
    end

    it "validates tool configuration" do
      expect do
        described_class.define_tool(
          :bad_tool,
          description: "Bad",
          inputs: {},
          output_type: "invalid_type"
        ) { "test" }
      end.to raise_error(ArgumentError, /Invalid output_type/)
    end
  end
end
