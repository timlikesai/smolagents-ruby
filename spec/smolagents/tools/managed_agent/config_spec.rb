RSpec.describe Smolagents::Tools::ManagedAgentTool::Config do
  let(:config) { described_class.new }

  describe "initialization" do
    it "initializes with nil values" do
      expect(config.agent_name).to be_nil
      expect(config.agent_description).to be_nil
      expect(config.prompt).to be_nil
    end
  end

  describe "#name" do
    it "sets the agent name" do
      result = config.name("researcher")

      expect(result).to eq("researcher")
      expect(config.agent_name).to eq("researcher")
    end

    it "returns the set value" do
      config.name("analyzer")

      expect(config.name("another_name")).to eq("another_name")
    end
  end

  describe "#description" do
    it "sets the agent description" do
      result = config.description("An agent that researches topics")

      expect(result).to eq("An agent that researches topics")
      expect(config.agent_description).to eq("An agent that researches topics")
    end

    it "returns the set value" do
      config.description("First description")

      expect(config.description("Second description")).to eq("Second description")
    end
  end

  describe "#prompt_template" do
    it "sets the prompt template" do
      template = "Research this: %<task>s"
      result = config.prompt_template(template)

      expect(result).to eq(template)
      expect(config.prompt).to eq(template)
    end

    it "returns the set value" do
      template1 = "Template 1: %<name>s %<task>s"
      config.prompt_template(template1)

      template2 = "Template 2: %<task>s"
      expect(config.prompt_template(template2)).to eq(template2)
    end
  end

  describe "#to_h" do
    it "returns empty hash for unset values" do
      hash = config.to_h

      expect(hash).to eq({ name: nil, description: nil, prompt_template: nil })
    end

    it "converts to hash with set values" do
      config.name("researcher")
      config.description("Researches topics")
      config.prompt_template("Research: %<task>s")

      hash = config.to_h

      expect(hash).to include(
        name: "researcher",
        description: "Researches topics",
        prompt_template: "Research: %<task>s"
      )
    end

    it "converts with mixed set and nil values" do
      config.name("analyzer")
      config.description("Analyzes data")

      hash = config.to_h

      expect(hash[:name]).to eq("analyzer")
      expect(hash[:description]).to eq("Analyzes data")
      expect(hash[:prompt_template]).to be_nil
    end
  end

  describe "setting values" do
    it "returns the set value, not self" do
      # Config methods return the set value, not self (not a fluent interface)
      config.name("tool")
      config.description("A tool")
      config.prompt_template("Template")

      expect(config.agent_name).to eq("tool")
      expect(config.agent_description).to eq("A tool")
      expect(config.prompt).to eq("Template")
    end
  end

  describe "configuration in class definition" do
    it "works with configure block in class" do
      class TestManagedAgent < Smolagents::Tools::ManagedAgentTool
        configure do |cfg|
          cfg.name "test_agent"
          cfg.description "Test agent description"
          cfg.prompt_template "Test: %<task>s"
        end
      end

      config_hash = TestManagedAgent.config.to_h

      expect(config_hash[:name]).to eq("test_agent")
      expect(config_hash[:description]).to eq("Test agent description")
      expect(config_hash[:prompt_template]).to eq("Test: %<task>s")
    end
  end

  describe "special characters in values" do
    it "handles special characters in name" do
      config.name("agent-with-dashes_and_underscores")

      expect(config.agent_name).to eq("agent-with-dashes_and_underscores")
    end

    it "handles multiline description" do
      description = "This is a\nmultiline\ndescription"
      config.description(description)

      expect(config.agent_description).to eq(description)
    end

    it "handles template with various placeholders" do
      template = "Name: %<name>s\nTask: %<task>s\nContext: %<context>s"
      config.prompt_template(template)

      expect(config.prompt).to eq(template)
    end
  end

  describe "immutability preservation" do
    it "allows reassignment of values" do
      config.name("first")
      expect(config.agent_name).to eq("first")

      config.name("second")
      expect(config.agent_name).to eq("second")
    end
  end
end
