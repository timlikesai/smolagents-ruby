require "spec_helper"
require "smolagents/cli/commands"

RSpec.describe Smolagents::CLI::Commands::Info do
  let(:test_class) do
    Class.new do
      include Smolagents::CLI::Commands::Info

      attr_reader :output

      def initialize
        @output = []
      end

      def say(message, color = nil)
        @output << { message:, color: }
      end
    end
  end

  let(:info) { test_class.new }

  describe "PROVIDER_EXAMPLES" do
    it "includes OpenAI examples" do
      examples = described_class::PROVIDER_EXAMPLES["OpenAI"]

      expect(examples).to include("--provider openai --model gpt-4")
      expect(examples).to include("--provider openai --model gpt-3.5-turbo")
    end

    it "includes Anthropic examples" do
      examples = described_class::PROVIDER_EXAMPLES["Anthropic"]

      expect(examples).to include("--provider anthropic --model claude-3-5-sonnet-20241022")
    end

    it "includes Local LM Studio examples" do
      examples = described_class::PROVIDER_EXAMPLES["Local (LM Studio)"]

      expect(examples.first).to include("localhost:1234")
    end

    it "includes Local Ollama examples" do
      examples = described_class::PROVIDER_EXAMPLES["Local (Ollama)"]

      expect(examples.first).to include("localhost:11434")
    end

    it "is frozen" do
      expect(described_class::PROVIDER_EXAMPLES).to be_frozen
    end
  end

  describe "#tools" do
    let(:mock_tool) { instance_double(Smolagents::Tool, description: "A useful tool") }
    let(:mock_tool_class) do
      tool = mock_tool
      Class.new { define_singleton_method(:new) { tool } }
    end

    before do
      stub_const("Smolagents::Tools::REGISTRY", {
                   "search" => mock_tool_class,
                   "calculator" => mock_tool_class
                 })
    end

    it "displays header in cyan" do
      info.tools

      header = info.output.find { it[:message] == "Available tools:" }
      expect(header[:color]).to eq(:cyan)
    end

    it "displays tool names in green" do
      info.tools

      tool_entries = info.output.select { it[:color] == :green }
      tool_names = tool_entries.map { it[:message] }

      expect(tool_names).to include("\n  search")
      expect(tool_names).to include("\n  calculator")
    end

    it "displays tool descriptions indented" do
      info.tools

      descriptions = info.output.select { it[:message]&.start_with?("    ") }
      expect(descriptions).not_to be_empty
    end

    it "iterates through all registry tools" do
      info.tools

      # Header + 2 tools (name + description each)
      expect(info.output.size).to eq(5)
    end
  end

  describe "#models" do
    it "displays header in cyan" do
      info.models

      header = info.output.find { it[:message] == "Model providers:" }
      expect(header[:color]).to eq(:cyan)
    end

    it "displays all provider sections" do
      info.models

      provider_entries = info.output.select { it[:color] == :green }
      provider_names = provider_entries.map { it[:message] }

      expect(provider_names).to include("\n  OpenAI:")
      expect(provider_names).to include("\n  Anthropic:")
      expect(provider_names).to include("\n  Local (LM Studio):")
      expect(provider_names).to include("\n  Local (Ollama):")
    end

    it "displays example commands" do
      info.models

      example_entries = info.output.select { it[:message]&.start_with?("    --provider") }
      expect(example_entries).not_to be_empty
    end
  end

  describe "#print_provider_examples" do
    it "displays provider name in green" do
      info.print_provider_examples("TestProvider", ["--example 1"])

      provider = info.output.find { it[:message] == "\n  TestProvider:" }
      expect(provider[:color]).to eq(:green)
    end

    it "displays each example indented" do
      examples = ["--example 1", "--example 2"]
      info.print_provider_examples("Test", examples)

      example_entries = info.output.select { it[:message]&.start_with?("    --") }
      expect(example_entries.size).to eq(2)
      expect(example_entries.map { it[:message] }).to include("    --example 1")
      expect(example_entries.map { it[:message] }).to include("    --example 2")
    end

    it "handles empty examples array" do
      info.print_provider_examples("Empty", [])

      expect(info.output.size).to eq(1)
      expect(info.output.first[:message]).to eq("\n  Empty:")
    end
  end
end
