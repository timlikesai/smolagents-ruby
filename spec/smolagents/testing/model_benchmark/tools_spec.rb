require "spec_helper"

RSpec.describe Smolagents::Testing::ModelBenchmark::BenchmarkTools do
  # Create a test class that includes the BenchmarkTools module
  let(:test_class) do
    Class.new do
      include Smolagents::Testing::ModelBenchmark::BenchmarkTools

      # Make private methods accessible for testing
      public :build_tools, :tool_for_symbol, :calculator_tool, :safe_eval
    end
  end

  let(:tools_builder) { test_class.new }

  describe "#build_tools" do
    it "builds array of tools from symbols" do
      tools = tools_builder.build_tools([:calculator])

      expect(tools.size).to eq(1)
      expect(tools.first).to be_a(Smolagents::Tools::Tool)
    end

    it "builds multiple tools" do
      # Only test calculator since search requires external URL
      tools = tools_builder.build_tools([:calculator])

      expect(tools.size).to eq(1)
    end

    it "returns empty array for empty input" do
      tools = tools_builder.build_tools([])

      expect(tools).to eq([])
    end
  end

  describe "#tool_for_symbol" do
    it "returns calculator tool for :calculator" do
      tool = tools_builder.tool_for_symbol(:calculator)

      expect(tool.tool_name).to eq("calculate")
    end

    it "raises ArgumentError for unknown symbol" do
      expect { tools_builder.tool_for_symbol(:unknown) }
        .to raise_error(ArgumentError, "Unknown tool: unknown")
    end
  end

  describe "#calculator_tool" do
    let(:calculator) { tools_builder.calculator_tool }

    it "creates a tool named 'calculate'" do
      expect(calculator.tool_name).to eq("calculate")
    end

    it "has proper description" do
      expect(calculator.description).to include("mathematical expression")
    end

    it "has expression input" do
      expect(calculator.inputs).to have_key(:expression)
      expect(calculator.inputs[:expression][:type]).to eq("string")
    end

    it "returns number output type" do
      expect(calculator.output_type).to eq("number")
    end

    it "memoizes the tool instance" do
      first_call = tools_builder.calculator_tool
      second_call = tools_builder.calculator_tool

      expect(first_call).to be(second_call)
    end
  end

  describe "#safe_eval" do
    it "evaluates simple addition" do
      expect(tools_builder.safe_eval("2 + 2")).to eq(4.0)
    end

    it "evaluates multiplication" do
      expect(tools_builder.safe_eval("15 * 7")).to eq(105.0)
    end

    it "evaluates subtraction" do
      expect(tools_builder.safe_eval("100 - 50")).to eq(50.0)
    end

    it "evaluates division" do
      expect(tools_builder.safe_eval("100 / 4")).to eq(25.0)
    end

    it "evaluates expressions with parentheses" do
      expect(tools_builder.safe_eval("(2 + 3) * 4")).to eq(20.0)
    end

    it "evaluates floating point numbers" do
      expect(tools_builder.safe_eval("3.14 * 2")).to be_within(0.01).of(6.28)
    end

    it "handles whitespace" do
      expect(tools_builder.safe_eval("  2   +   2  ")).to eq(4.0)
    end

    it "strips alphabetic characters for safety" do
      # Letters are stripped, keeping only digits and operators
      expect(tools_builder.safe_eval("2abc3")).to eq(23.0)
    end

    it "handles string input" do
      expect(tools_builder.safe_eval(42)).to eq(42.0)
    end
  end

  describe "calculator tool properties" do
    let(:calculator) { tools_builder.calculator_tool }

    it "is a valid Tool instance" do
      expect(calculator).to be_a(Smolagents::Tools::Tool)
      expect(calculator.tool_name).to eq("calculate")
    end

    it "has correct schema for agent use" do
      expect(calculator.inputs).to be_a(Hash)
      expect(calculator.output_type).to eq("number")
      expect(calculator.description).to be_a(String)
    end
  end
end
