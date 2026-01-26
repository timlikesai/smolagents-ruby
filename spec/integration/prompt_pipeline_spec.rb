require "spec_helper"

RSpec.describe "Prompt Pipeline Integration", type: :integration do
  # These tests verify prompt generation and observation formatting
  # WITHOUT hitting real models - they're instant and catch integration bugs.

  let(:mock_model) { Smolagents::Testing::MockModel.new }

  describe "Context Provider Pipeline" do
    it "generates system prompt without internal errors" do
      # This catches Bug #2 - errors leaking into prompts
      agent = Smolagents.agent.model { mock_model }.build
      system_content = agent.system_prompt

      # Should NOT contain error messages
      expect(system_content).not_to include("[Error from")
      expect(system_content).not_to include("undefined method")
      expect(system_content).not_to include("NoMethodError")
    end

    it "includes tool signatures with parameter names" do
      # This catches Bug #1 - missing tool parameters
      add_tool = ->(a:, b:) { a + b }
      agent = Smolagents.agent
                        .model { mock_model }
                        .tool(:add, "Add two numbers", a: Integer, b: Integer, &add_tool)
                        .build

      system_content = agent.system_prompt

      # Should show parameter names
      expect(system_content).to include("add(")
      expect(system_content).to include("a:")
    end
  end

  describe "StructureFormatting" do
    subject(:formatting) { Smolagents::Concerns::StructureFormatting }

    it "shows actual values for small primitive arrays" do
      # This catches Bug #3 - losing values in Array[N] format
      result = formatting.describe([2, 4, 6])

      expect(result).to include("2")
      expect(result).to include("4")
      expect(result).to include("6")
      # Should NOT hide values behind Array[3] for small arrays
    end

    it "handles Range values gracefully" do
      # This catches part of Bug #6 - Range causing errors
      result = formatting.describe(1..10)

      expect(result).to include("1..10")
      expect(result).not_to include("Error")
    end

    it "shows actual string values" do
      result = formatting.describe("hello world")
      expect(result).to include("hello world")
    end

    it "describes hash with keys" do
      result = formatting.describe({ name: "Alice", age: 30 })

      expect(result).to include(":name")
      expect(result).to include(":age")
    end
  end

  describe "Observation Building" do
    # Test the observation pipeline without executing actual code

    it "filters iterator noise (Range) from observations" do
      # This catches Bug #6 - iterator return values confusing models
      concern = Class.new do
        include Smolagents::Concerns::CodeExecution

        def initialize
          @max_steps = 10
        end
      end.new

      # Range should be considered noise
      expect(concern.send(:iterator_noise?, 1..5)).to be true
      expect(concern.send(:iterator_noise?, [1, 2].each)).to be true

      # Real values should not be noise
      expect(concern.send(:iterator_noise?, [1, 2, 3])).to be false
      expect(concern.send(:iterator_noise?, "result")).to be false
      expect(concern.send(:iterator_noise?, 42)).to be false
    end
  end

  describe "Tool Formatting Contract" do
    # Verify the contract between tool definitions and prompt formatting

    it "InlineTool preserves input types for formatting" do
      tool = Smolagents::Tools::InlineTool.create(
        :greet,
        "Greet a person",
        name: String
      ) { |name:| "Hello, #{name}!" }

      # Inputs should be preserved
      expect(tool.inputs).to have_key(:name)
      expect(tool.inputs[:name][:type]).to eq("string")
    end

    it "Tool formatter generates callable signatures" do
      tool = Smolagents::Tools::InlineTool.create(
        :add,
        "Add numbers",
        a: Integer,
        b: Integer
      ) { |a:, b:| a + b }

      formatted = tool.format_for(:default)

      # Should be a callable Ruby method signature
      expect(formatted).to match(/add\(.*a:.*,.*b:.*\)/)
      expect(formatted).to include("Add numbers")
    end
  end
end
