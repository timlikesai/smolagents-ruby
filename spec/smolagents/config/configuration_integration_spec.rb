RSpec.describe "Configuration Integration" do
  let(:mock_model) do
    instance_double(Smolagents::Model, model_id: "test-model")
  end

  let(:mock_tool) do
    tool = instance_double(Smolagents::Tool)
    allow(tool).to receive_messages(
      name: "test_tool",
      description: "A test tool",
      inputs: { query: { type: "string", description: "Query string" } },
      to_code_prompt: "def test_tool\nend",
      to_tool_calling_prompt: "test_tool: description"
    )
    tool
  end

  before do
    Smolagents.reset_configuration!
  end

  describe "Agent with global configuration" do
    it "uses global custom_instructions" do
      Smolagents.configure do |config|
        config.custom_instructions = "Always cite sources"
      end

      agent = Smolagents::Agents::Agent.new(
        tools: [mock_tool],
        model: mock_model
      )

      prompt = agent.system_prompt
      expect(prompt).to include("Always cite sources")
    end

    it "uses global max_steps" do
      Smolagents.configure do |config|
        config.max_steps = 15
      end

      agent = Smolagents::Agents::Agent.new(
        tools: [mock_tool],
        model: mock_model
      )

      expect(agent.max_steps).to eq(15)
    end

    it "uses global authorized_imports" do
      Smolagents.configure do |config|
        config.authorized_imports = %w[json csv]
      end

      agent = Smolagents::Agents::Agent.new(
        tools: [mock_tool],
        model: mock_model
      )

      expect(agent.authorized_imports).to eq(%w[json csv])
    end
  end

  describe "Agent with per-agent override" do
    it "overrides global custom_instructions" do
      Smolagents.configure do |config|
        config.custom_instructions = "Global instructions"
      end

      agent = Smolagents::Agents::Agent.new(
        tools: [mock_tool],
        model: mock_model,
        custom_instructions: "Agent-specific instructions"
      )

      prompt = agent.system_prompt
      expect(prompt).to include("Agent-specific instructions")
      expect(prompt).not_to include("Global instructions")
    end

    it "overrides global max_steps" do
      Smolagents.configure do |config|
        config.max_steps = 15
      end

      agent = Smolagents::Agents::Agent.new(
        tools: [mock_tool],
        model: mock_model,
        max_steps: 25
      )

      expect(agent.max_steps).to eq(25)
    end

    it "overrides global authorized_imports" do
      Smolagents.configure do |config|
        config.authorized_imports = ["json"]
      end

      agent = Smolagents::Agents::Agent.new(
        tools: [mock_tool],
        model: mock_model,
        authorized_imports: %w[csv yaml]
      )

      expect(agent.authorized_imports).to eq(%w[csv yaml])
    end
  end

  describe "Sanitization in agents" do
    it "sanitizes custom_instructions with control characters" do
      agent = Smolagents::Agents::Agent.new(
        tools: [mock_tool],
        model: mock_model,
        custom_instructions: "Test\x00\x01invalid"
      )

      prompt = agent.system_prompt
      expect(prompt).to include("Testinvalid")
      expect(prompt).not_to include("\x00")
    end

    it "truncates long custom_instructions" do
      long_text = "a" * 10_000

      agent = Smolagents::Agents::Agent.new(
        tools: [mock_tool],
        model: mock_model,
        custom_instructions: long_text
      )

      prompt = agent.system_prompt
      expect(prompt.scan(/a+/).first.length).to be <= 5000
    end

    it "handles nil custom_instructions gracefully" do
      agent = Smolagents::Agents::Agent.new(
        tools: [mock_tool],
        model: mock_model,
        custom_instructions: nil
      )

      prompt = agent.system_prompt
      expect(prompt).to be_a(String)
      expect(prompt).to include("Ruby")
    end
  end

  describe "factory method integration" do
    it "respects global configuration in factory methods" do
      Smolagents.configure do |config|
        config.custom_instructions = "Factory test"
        config.max_steps = 8
      end

      simple_tool = Class.new(Smolagents::Tool) do
        def self.tool_name = "test_tool"
        def self.description = "Test tool"
        def self.inputs = {}
        def self.output_type = "string"

        def execute
          "test"
        end
      end.new

      agent = Smolagents.agent.model { mock_model }.tools(simple_tool).build

      expect(agent.max_steps).to eq(8)
      expect(agent.system_prompt).to include("Factory test")
    end
  end
end
