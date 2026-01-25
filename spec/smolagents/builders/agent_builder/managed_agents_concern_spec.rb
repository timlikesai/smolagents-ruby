require "spec_helper"

RSpec.describe Smolagents::Builders::ManagedAgentsConcern do
  include_context "with mocked tools"
  include_context "with mocked model"

  let(:builder_class) { Smolagents::Builders::AgentBuilder }
  let(:builder) { builder_class.create }

  describe "#managed_agent" do
    context "with an Agent instance" do
      let(:sub_agent) { instance_double(Smolagents::Agents::Agent) }

      it "adds the agent to managed_agents" do
        result = builder.managed_agent(sub_agent, as: "researcher")

        expect(result.config[:managed_agents]["researcher"]).to eq(sub_agent)
      end

      it "converts symbol names to strings" do
        result = builder.managed_agent(sub_agent, as: :helper)

        expect(result.config[:managed_agents]["helper"]).to eq(sub_agent)
      end

      it "returns a new builder instance (immutability)" do
        result = builder.managed_agent(sub_agent, as: "test")

        expect(result).not_to equal(builder)
        expect(result).to be_a(builder_class)
      end

      it "does not mutate the original builder" do
        original_managed = builder.config[:managed_agents].dup
        builder.managed_agent(sub_agent, as: "test")

        expect(builder.config[:managed_agents]).to eq(original_managed)
      end
    end

    context "with an AgentBuilder" do
      let(:sub_builder) do
        builder_class.create.model { mock_model }.tools(mock_search_tool)
      end

      before do
        allow(mock_model).to receive(:is_a?).and_return(true)
      end

      it "builds the agent from the builder" do
        result = builder.managed_agent(sub_builder, as: "helper")

        expect(result.config[:managed_agents]["helper"]).to be_a(Smolagents::Agents::Agent)
      end

      it "builds at configuration time, not at parent build time" do
        # The sub-builder is built when managed_agent is called
        result = builder.managed_agent(sub_builder, as: "helper")

        expect(result.config[:managed_agents]["helper"]).to be_a(Smolagents::Agents::Agent)
      end
    end

    context "with multiple managed agents" do
      let(:agent1) { instance_double(Smolagents::Agents::Agent) }
      let(:agent2) { instance_double(Smolagents::Agents::Agent) }

      it "accumulates managed agents" do
        result = builder
                 .managed_agent(agent1, as: "researcher")
                 .managed_agent(agent2, as: "writer")

        expect(result.config[:managed_agents].keys).to contain_exactly("researcher", "writer")
        expect(result.config[:managed_agents]["researcher"]).to eq(agent1)
        expect(result.config[:managed_agents]["writer"]).to eq(agent2)
      end

      it "replaces agent with same name" do
        result = builder
                 .managed_agent(agent1, as: "helper")
                 .managed_agent(agent2, as: "helper")

        expect(result.config[:managed_agents]["helper"]).to eq(agent2)
      end
    end
  end
end
