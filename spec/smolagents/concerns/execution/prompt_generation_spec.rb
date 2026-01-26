require "smolagents/concerns/execution/prompt_generation"

RSpec.describe Smolagents::Concerns::PromptGeneration do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::PromptGeneration

      attr_accessor :tools, :managed_agents, :custom_instructions

      def initialize
        @tools = {}
        @managed_agents = nil
        @custom_instructions = nil
      end

      # Stub method to generate managed agent descriptions
      def managed_agent_descriptions
        return nil unless @managed_agents

        @managed_agents.map { |name, _agent| "Agent: #{name}" }.join("\n")
      end
    end
  end

  let(:instance) { test_class.new }

  describe "#template_path" do
    it "returns nil by default" do
      path = instance.template_path
      expect(path).to be_nil
    end

    it "can be overridden in subclass" do
      subclass = Class.new(test_class) do
        def template_path
          "/custom/templates"
        end
      end

      expect(subclass.new.template_path).to eq("/custom/templates")
    end
  end

  describe "#system_prompt" do
    before do
      # Mock the Prompts::Agent.generate method
      allow(Smolagents::Prompts::Agent).to receive(:generate).and_return(
        "You are a helpful agent that solves tasks by writing Ruby code."
      )
      allow(Smolagents::Prompts).to receive(:generate_capabilities).and_return("")
    end

    it "returns a non-empty string" do
      prompt = instance.system_prompt
      expect(prompt).to be_a(String)
      expect(prompt).not_to be_empty
    end

    it "calls Prompts::Agent.generate" do
      instance.system_prompt

      expect(Smolagents::Prompts::Agent).to have_received(:generate)
    end

    it "includes tools in generation" do
      tool = instance_double(Smolagents::Tool, name: "search")
      instance.tools = { "search" => tool }

      instance.system_prompt

      expect(Smolagents::Prompts::Agent).to have_received(:generate) do |kwargs|
        expect(kwargs[:tools]).to eq([tool])
      end
    end

    it "includes managed agents if present" do
      instance.managed_agents = { "searcher" => double("agent") }

      instance.system_prompt

      expect(Smolagents::Prompts::Agent).to have_received(:generate) do |kwargs|
        expect(kwargs[:team]).not_to be_nil
      end
    end

    it "passes nil for team if no managed agents" do
      instance.managed_agents = nil

      instance.system_prompt

      expect(Smolagents::Prompts::Agent).to have_received(:generate) do |kwargs|
        expect(kwargs[:team]).to be_nil
      end
    end

    it "includes custom instructions if provided" do
      instance.custom_instructions = "Be very thorough in your analysis"

      instance.system_prompt

      expect(Smolagents::Prompts::Agent).to have_received(:generate) do |kwargs|
        expect(kwargs[:custom]).to eq("Be very thorough in your analysis")
      end
    end

    it "passes nil for custom if not provided" do
      instance.custom_instructions = nil

      instance.system_prompt

      expect(Smolagents::Prompts::Agent).to have_received(:generate) do |kwargs|
        expect(kwargs[:custom]).to be_nil
      end
    end
  end

  describe "#system_prompt with capabilities" do
    let(:base_prompt) { "Base agent prompt" }
    let(:capabilities_prompt) { "Capabilities: search, parse, write" }

    before do
      allow(Smolagents::Prompts::Agent).to receive(:generate).and_return(base_prompt)
      allow(Smolagents::Prompts).to receive(:generate_capabilities).and_return(capabilities_prompt)
    end

    it "appends capabilities when present" do
      prompt = instance.system_prompt

      expect(prompt).to include(base_prompt)
      expect(prompt).to include(capabilities_prompt)
    end

    it "separates base and capabilities with double newline" do
      prompt = instance.system_prompt

      expect(prompt).to include("#{base_prompt}\n\n#{capabilities_prompt}")
    end

    it "returns base only when capabilities empty" do
      allow(Smolagents::Prompts).to receive(:generate_capabilities).and_return("")

      prompt = instance.system_prompt

      expect(prompt).to eq(base_prompt)
    end
  end

  describe "#capabilities_prompt" do
    before do
      allow(Smolagents::Prompts).to receive(:generate_capabilities).and_return(
        "Tool usage patterns and capabilities"
      )
    end

    it "calls Prompts.generate_capabilities" do
      instance.capabilities_prompt

      expect(Smolagents::Prompts).to have_received(:generate_capabilities)
    end

    it "includes tools in capabilities generation" do
      tool = instance_double(Smolagents::Tool, name: "search")
      instance.tools = { "search" => tool }

      instance.capabilities_prompt

      expect(Smolagents::Prompts).to have_received(:generate_capabilities) do |kwargs|
        expect(kwargs[:tools]).not_to be_nil
      end
    end

    it "includes managed agents in capabilities" do
      instance.managed_agents = { "searcher" => double("agent") }

      instance.capabilities_prompt

      expect(Smolagents::Prompts).to have_received(:generate_capabilities) do |kwargs|
        expect(kwargs[:managed_agents]).not_to be_nil
      end
    end

    it "returns capabilities string" do
      capabilities = instance.capabilities_prompt

      expect(capabilities).to be_a(String)
    end

    it "can return empty string" do
      allow(Smolagents::Prompts).to receive(:generate_capabilities).and_return("")

      capabilities = instance.capabilities_prompt

      expect(capabilities).to eq("")
    end
  end

  describe "prompt generation flow" do
    before do
      allow(Smolagents::Prompts::Agent).to receive(:generate).and_return("Agent instructions")
      allow(Smolagents::Prompts).to receive(:generate_capabilities).and_return("Capabilities")
    end

    it "generates complete system prompt" do
      tool1 = instance_double(Smolagents::Tool, name: "search")
      tool2 = instance_double(Smolagents::Tool, name: "parse")
      instance.tools = { "search" => tool1, "parse" => tool2 }
      instance.custom_instructions = "Custom behavior"
      instance.managed_agents = { "worker" => double("agent") }

      prompt = instance.system_prompt

      expect(prompt).to be_a(String)
      expect(prompt).to include("Agent instructions")
      expect(prompt).to include("Capabilities")
    end

    it "handles agent with no tools" do
      instance.tools = {}

      expect do
        instance.system_prompt
      end.not_to raise_error
    end

    it "handles agent with no custom instructions" do
      instance.custom_instructions = nil

      expect do
        instance.system_prompt
      end.not_to raise_error
    end

    it "handles agent with no managed agents" do
      instance.managed_agents = nil

      expect do
        instance.system_prompt
      end.not_to raise_error
    end
  end

  describe "prompt parameters" do
    before do
      allow(Smolagents::Prompts::Agent).to receive(:generate).and_return("prompt")
      allow(Smolagents::Prompts).to receive(:generate_capabilities).and_return("")
    end

    it "passes all required parameters to Agent.generate" do
      tool = instance_double(Smolagents::Tool)
      instance.tools = { "tool" => tool }
      instance.custom_instructions = "Test instructions"

      instance.system_prompt

      expect(Smolagents::Prompts::Agent).to have_received(:generate).with(
        hash_including(
          tools: [tool],
          team: nil,
          custom: "Test instructions"
        )
      )
    end

    it "extracts tools as array from hash" do
      tool1 = instance_double(Smolagents::Tool, name: "t1")
      tool2 = instance_double(Smolagents::Tool, name: "t2")
      instance.tools = { "tool1" => tool1, "tool2" => tool2 }

      instance.system_prompt

      expect(Smolagents::Prompts::Agent).to have_received(:generate) do |kwargs|
        expect(kwargs[:tools]).to contain_exactly(tool1, tool2)
      end
    end
  end

  describe "customization hooks" do
    it "allows subclass to customize template_path" do
      custom_class = Class.new(test_class) do
        def template_path
          "custom/path"
        end
      end

      instance = custom_class.new
      expect(instance.template_path).to eq("custom/path")
    end

    it "allows subclass to override system_prompt completely" do
      custom_class = Class.new(test_class) do
        def system_prompt
          "Completely custom prompt"
        end
      end

      instance = custom_class.new
      expect(instance.system_prompt).to eq("Completely custom prompt")
    end

    it "allows subclass to customize capabilities" do
      custom_class = Class.new(test_class) do
        def capabilities_prompt
          "Custom capabilities"
        end
      end

      allow(Smolagents::Prompts::Agent).to receive(:generate).and_return("Base")

      instance = custom_class.new
      prompt = instance.system_prompt

      expect(prompt).to include("Custom capabilities")
    end
  end
end
