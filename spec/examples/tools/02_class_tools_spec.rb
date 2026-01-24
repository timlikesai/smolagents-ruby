require "spec_helper"
require_relative "../../../examples/tools/02_class_tools"

RSpec.describe "Example: Class-Based Tools", type: :example do
  include Smolagents::Testing::Helpers::ModelHelpers

  describe TemperatureConverter do
    let(:tool) { described_class.new }

    it "has correct metadata" do
      expect(tool.tool_name).to eq("convert_temp")
      expect(tool.description).to include("temperature")
    end

    it "converts Celsius to Fahrenheit" do
      result = tool.call(value: 100, from_unit: "C")

      expect(result.data[:value]).to eq(212.0)
      expect(result.data[:unit]).to eq("F")
    end

    it "converts Fahrenheit to Celsius" do
      result = tool.call(value: 32, from_unit: "F")

      expect(result.data[:value]).to eq(0.0)
      expect(result.data[:unit]).to eq("C")
    end

    it "handles lowercase units" do
      result = tool.call(value: 0, from_unit: "c")

      expect(result.data[:value]).to eq(32.0)
    end

    it "raises on unknown unit" do
      expect { tool.call(value: 100, from_unit: "K") }
        .to raise_error(ArgumentError, /Unknown unit/)
    end
  end

  describe CounterTool do
    let(:tool) { described_class.new }

    it "has correct metadata" do
      expect(tool.tool_name).to eq("counter")
    end

    it "starts at zero and increments" do
      expect(tool.call.data).to eq(1)
      expect(tool.call.data).to eq(2)
      expect(tool.call.data).to eq(3)
    end

    it "maintains separate state per instance" do
      tool1 = described_class.new
      tool2 = described_class.new

      tool1.call
      tool1.call

      expect(tool1.call.data).to eq(3)
      expect(tool2.call.data).to eq(1)
    end
  end

  describe SearchTool do
    it "uses default max_results" do
      tool = described_class.new
      result = tool.call(query: "ruby")

      expect(result.data.size).to eq(5)
    end

    it "accepts custom max_results" do
      tool = described_class.new(max_results: 3)
      result = tool.call(query: "ruby")

      expect(result.data.size).to eq(3)
    end

    it "includes query in results" do
      tool = described_class.new(max_results: 1)
      result = tool.call(query: "test query")

      expect(result.data.first).to include("test query")
    end
  end

  describe AnalysisTool do
    let(:tool) { described_class.new }

    it "has output schema defined" do
      expect(tool.class.output_schema).to have_key(:word_count)
      expect(tool.class.output_schema).to have_key(:char_count)
      expect(tool.class.output_schema).to have_key(:sentence_count)
    end

    it "analyzes text correctly" do
      result = tool.call(text: "Hello world. This is a test!")

      expect(result.data[:word_count]).to eq(6)
      expect(result.data[:char_count]).to eq(28)
      expect(result.data[:sentence_count]).to eq(2)
    end

    it "handles empty text" do
      result = tool.call(text: "")

      expect(result.data[:word_count]).to eq(0)
      expect(result.data[:char_count]).to eq(0)
    end
  end

  describe "create_agent_with_class_tools" do
    it "registers all tools" do
      model = mock_model { |m| m.queue_final_answer("done") }
      agent = create_agent_with_class_tools(model)

      expect(agent.tools.keys).to include("convert_temp", "counter", "search")
    end

    it "tools work through agent" do
      model = mock_model do |m|
        m.queue_code_action('final_answer(answer: convert_temp(value: 100, from_unit: "C"))')
      end
      agent = create_agent_with_class_tools(model)

      result = agent.run("Convert 100C to Fahrenheit")

      expect(result.output[:value]).to eq(212.0)
      expect(result.output[:unit]).to eq("F")
    end

    it "search respects configured max_results" do
      model = mock_model do |m|
        m.queue_code_action('final_answer(answer: search(query: "ruby"))')
      end
      agent = create_agent_with_class_tools(model)

      result = agent.run("Search for ruby")

      expect(result.output.size).to eq(3) # configured to 3 in example
    end
  end

  describe "tool lifecycle" do
    it "setup is called automatically on first use" do
      tool = CounterTool.new
      expect(tool.initialized?).to be false

      tool.call
      expect(tool.initialized?).to be true
    end

    it "setup is only called once" do
      tool = CounterTool.new

      3.times { tool.call }

      # Counter would be different if setup was called multiple times
      expect(tool.call.data).to eq(4)
    end
  end

  describe "ToolResult wrapping" do
    it "call returns ToolResult" do
      tool = TemperatureConverter.new
      result = tool.call(value: 0, from_unit: "C")

      expect(result).to be_a(Smolagents::ToolResult)
      expect(result.tool_name).to eq("convert_temp")
    end

    it "ToolResult provides data access" do
      tool = AnalysisTool.new
      result = tool.call(text: "Hello world")

      expect(result.data).to be_a(Hash)
      expect(result[:word_count]).to eq(2)
    end
  end
end
