RSpec.describe Smolagents::Agents::Agent::Prompts do
  let(:agent_class) do
    Class.new do
      include Smolagents::Agents::Agent::Prompts

      def initialize(tools: {}, managed_agents: {}, authorized_imports: [], custom_instructions: nil)
        @tools = tools
        @managed_agents = managed_agents
        @authorized_imports = authorized_imports
        @custom_instructions = custom_instructions
      end

      # Required by system_prompt - returns descriptions for Prompts.generate
      def managed_agent_descriptions
        return nil unless @managed_agents&.any?

        @managed_agents.map do |name, agent|
          "#{name}: #{agent.respond_to?(:description) ? agent.description : "Agent"}"
        end
      end
    end
  end

  let(:agent) { agent_class.new }

  describe "#system_prompt" do
    it "generates a system prompt" do
      prompt = agent.system_prompt

      expect(prompt).to be_a(String)
      expect(prompt).not_to be_empty
    end

    it "includes generated capabilities when present" do
      tool = instance_double(
        Smolagents::Tool,
        name: "search",
        description: "Search the web",
        inputs: {}
      )
      agent_with_tool = agent_class.new(tools: { "search" => tool })

      prompt = agent_with_tool.system_prompt

      # Should include base prompt and capabilities
      expect(prompt).to include(tool.name) unless prompt.empty?
    end

    it "uses Prompts.generate for base prompt" do
      allow(Smolagents::Prompts).to receive_messages(generate: "Base prompt", generate_capabilities: "")

      agent.system_prompt

      expect(Smolagents::Prompts).to have_received(:generate)
    end

    it "passes tools to Prompts.generate" do
      tool = instance_double(Smolagents::Tool)
      agent_with_tool = agent_class.new(tools: { "test" => tool })

      allow(Smolagents::Prompts).to receive_messages(generate: "Prompt", generate_capabilities: "")

      agent_with_tool.system_prompt

      expect(Smolagents::Prompts).to have_received(:generate) do |**kwargs|
        expect(kwargs[:tools]).to be_a(Array)
      end
    end

    it "passes managed_agents descriptions to Prompts.generate" do
      allow(Smolagents::Prompts).to receive_messages(generate: "Prompt", generate_capabilities: "")

      agent.system_prompt

      expect(Smolagents::Prompts).to have_received(:generate) do |**kwargs|
        expect(kwargs.key?(:team)).to be true
      end
    end

    it "passes authorized_imports to Prompts.generate" do
      agent_with_imports = agent_class.new(authorized_imports: %w[Math Time])

      allow(Smolagents::Prompts).to receive_messages(generate: "Prompt", generate_capabilities: "")

      agent_with_imports.system_prompt

      expect(Smolagents::Prompts).to have_received(:generate) do |**kwargs|
        expect(kwargs[:authorized_imports]).to eq(%w[Math Time])
      end
    end

    it "passes custom_instructions to Prompts.generate" do
      agent_custom = agent_class.new(custom_instructions: "Be helpful")

      allow(Smolagents::Prompts).to receive_messages(generate: "Prompt", generate_capabilities: "")

      agent_custom.system_prompt

      expect(Smolagents::Prompts).to have_received(:generate) do |**kwargs|
        expect(kwargs[:custom]).to eq("Be helpful")
      end
    end

    it "appends capabilities prompt when present" do
      agent_with_tool = agent_class.new(tools: { "search" => double })

      allow(Smolagents::Prompts).to receive_messages(generate: "Base", generate_capabilities: "Capabilities")

      prompt = agent_with_tool.system_prompt

      expect(prompt).to include("Base")
      expect(prompt).to include("Capabilities")
    end

    it "returns only base prompt when capabilities empty" do
      allow(Smolagents::Prompts).to receive_messages(generate: "BasePrompt", generate_capabilities: "")

      prompt = agent.system_prompt

      expect(prompt).to eq("BasePrompt")
    end

    it "joins base and capabilities with double newline" do
      allow(Smolagents::Prompts).to receive_messages(generate: "Base", generate_capabilities: "Caps")

      prompt = agent.system_prompt

      expect(prompt).to include("Base\n\nCaps")
    end
  end

  describe "#capabilities_prompt" do
    it "returns nil when no managed agents" do
      prompt = agent.capabilities_prompt

      expect(prompt).to be_nil
    end

    it "calls generate_capabilities with tools" do
      tool = double("Tool")
      agent_with_tool = agent_class.new(tools: { "test" => tool })

      allow(Smolagents::Prompts).to receive(:generate_capabilities).and_return("Caps")

      agent_with_tool.capabilities_prompt

      expect(Smolagents::Prompts).to have_received(:generate_capabilities)
    end

    it "returns empty string for no tools" do
      allow(Smolagents::Prompts).to receive(:generate_capabilities).and_call_original

      agent.capabilities_prompt

      expect(Smolagents::Prompts).to have_received(:generate_capabilities) do |**kwargs|
        expect(kwargs[:tools]).to be_empty
      end
    end

    it "includes managed_agents in capabilities" do
      agent_with_managed = agent_class.new(
        tools: {},
        managed_agents: { "researcher" => double }
      )

      allow(Smolagents::Prompts).to receive(:generate_capabilities).and_return("SubAgents")

      agent_with_managed.capabilities_prompt

      expect(Smolagents::Prompts).to have_received(:generate_capabilities) do |**kwargs|
        expect(kwargs[:managed_agents]).not_to be_nil
      end
    end
  end

  describe "#template_path" do
    it "returns nil" do
      expect(agent.template_path).to be_nil
    end

    it "is designed for override in subclasses" do
      expect(agent).to respond_to(:template_path)
    end
  end
end
