require "spec_helper"

# rubocop:disable RSpec/DescribeClass -- integration test for event emission

RSpec.describe "Builder Configuration Events" do
  def mock_model
    Smolagents::Testing::MockModel.new.tap { |m| m.queue_final_answer("done") }
  end

  before do
    Smolagents::Events::CreateFactory.reset_sequence!
  end

  describe "AgentConfigured event" do
    it "is emitted after agent.build" do
      received = []

      agent = Smolagents.agent
                        .model { mock_model }
                        .on(:agent_configured) { |e| received << e }
                        .build

      Smolagents::Events::AsyncQueue.drain(timeout: 1)

      expect(agent).to be_a(Smolagents::Agents::Agent)
      expect(received.size).to eq(1)
      expect(received.first).to be_a(Smolagents::Events::AgentConfigured)
    end

    it "includes agent_name from persona" do
      received = []

      Smolagents.agent
                .model { mock_model }
                .as(:researcher)
                .on(:agent_configured) { |e| received << e }
                .build

      Smolagents::Events::AsyncQueue.drain(timeout: 1)

      expect(received.first.agent_name).to eq("researcher")
    end

    it "uses 'unnamed' when no persona is set" do
      received = []

      Smolagents.agent
                .model { mock_model }
                .on(:agent_configured) { |e| received << e }
                .build

      Smolagents::Events::AsyncQueue.drain(timeout: 1)

      expect(received.first.agent_name).to eq("unnamed")
    end

    it "includes accurate tool list from tool names" do
      received = []

      Smolagents.agent
                .model { mock_model }
                .tools(:duckduckgo_search, :visit_webpage)
                .on(:agent_configured) { |e| received << e }
                .build

      Smolagents::Events::AsyncQueue.drain(timeout: 1)

      tools = received.first.tools
      expect(tools).to include("duckduckgo_search")
      expect(tools).to include("visit_webpage")
    end

    it "includes accurate tool list from tool instances" do
      received = []
      search_tool = Smolagents::Tools::DuckDuckGoSearchTool.new

      Smolagents.agent
                .model { mock_model }
                .tools(search_tool)
                .on(:agent_configured) { |e| received << e }
                .build

      Smolagents::Events::AsyncQueue.drain(timeout: 1)

      tools = received.first.tools
      expect(tools).to include("duckduckgo_search")
    end

    it "lists default model purpose when single model configured" do
      received = []

      Smolagents.agent
                .model { mock_model }
                .on(:agent_configured) { |e| received << e }
                .build

      Smolagents::Events::AsyncQueue.drain(timeout: 1)

      expect(received.first.model_purposes).to eq([:execution])
    end

    it "lists all model purposes when multi-model configured" do
      received = []

      Smolagents.agent
                .model(:execution) { mock_model }
                .model(:planning) { mock_model }
                .on(:agent_configured) { |e| received << e }
                .build

      Smolagents::Events::AsyncQueue.drain(timeout: 1)

      purposes = received.first.model_purposes
      expect(purposes).to contain_exactly(:execution, :planning)
    end

    it "freezes the tools array" do
      received = []

      Smolagents.agent
                .model { mock_model }
                .tools(:duckduckgo_search)
                .on(:agent_configured) { |e| received << e }
                .build

      Smolagents::Events::AsyncQueue.drain(timeout: 1)

      expect(received.first.tools).to be_frozen
    end

    it "freezes the model_purposes array" do
      received = []

      Smolagents.agent
                .model { mock_model }
                .on(:agent_configured) { |e| received << e }
                .build

      Smolagents::Events::AsyncQueue.drain(timeout: 1)

      expect(received.first.model_purposes).to be_frozen
    end

    it "emits even when no other handlers are registered" do
      received = []

      Smolagents.agent
                .model { mock_model }
                .on(:agent_configured) { |e| received << e }
                .build

      Smolagents::Events::AsyncQueue.drain(timeout: 1)

      expect(received.size).to eq(1)
      expect(received.first.agent_name).to eq("unnamed")
    end
  end

  describe "event mapping" do
    it "maps :agent_configured to AgentConfigured" do
      event_class = Smolagents::Events::Mappings.resolve(:agent_configured)
      expect(event_class).to eq(Smolagents::Events::AgentConfigured)
    end
  end
end
# rubocop:enable RSpec/DescribeClass
