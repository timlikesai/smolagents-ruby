require "spec_helper"

# rubocop:disable RSpec/DescribeClass -- integration spec
RSpec.describe "AgentBuilder orchestration DSL" do
  let(:mock_model) { Smolagents::Testing::MockModel.new }

  describe "#event_driven" do
    it "enables event-driven mode" do
      builder = Smolagents.agent.model { mock_model }.event_driven
      expect(builder.config[:event_driven]).to be true
    end

    it "can be explicitly disabled" do
      builder = Smolagents.agent.model { mock_model }.event_driven(enabled: false)
      expect(builder.config[:event_driven]).to be false
    end

    it "defaults to false" do
      builder = Smolagents.agent.model { mock_model }
      expect(builder.config[:event_driven]).to be false
    end
  end

  describe "#orchestrator" do
    let(:orchestrator) { Smolagents::Orchestrators::EventOrchestrator.new }

    after { orchestrator.stop if orchestrator.running? }

    it "sets the orchestrator" do
      builder = Smolagents.agent.model { mock_model }.orchestrator(orchestrator)
      expect(builder.config[:orchestrator]).to eq(orchestrator)
    end

    it "implicitly enables event_driven" do
      builder = Smolagents.agent.model { mock_model }.orchestrator(orchestrator)
      expect(builder.config[:event_driven]).to be true
    end
  end

  describe "#step_timeout" do
    it "sets the step timeout" do
      builder = Smolagents.agent.model { mock_model }.step_timeout(30)
      expect(builder.config[:step_timeout]).to eq(30)
    end
  end

  describe "building event-driven agents" do
    it "creates an agent with EventDriven concern" do
      mock_model.queue_final_answer("done")
      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(:final_answer)
                        .event_driven
                        .build

      expect(agent).to respond_to(:run_async)
    end

    it "configures step timeout on agent" do
      mock_model.queue_final_answer("done")
      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(:final_answer)
                        .event_driven
                        .step_timeout(60)
                        .build

      expect(agent.step_timeout).to eq(60)
    end

    it "connects orchestrator when provided" do
      orchestrator = Smolagents::Orchestrators::EventOrchestrator.new
      mock_model.queue_final_answer("done")

      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(:final_answer)
                        .orchestrator(orchestrator)
                        .build

      expect(agent.async_stats[:orchestrator_connected]).to be true
      orchestrator.stop if orchestrator.running?
    end
  end

  describe "chaining" do
    it "supports full fluent chain" do
      orchestrator = Smolagents::Orchestrators::EventOrchestrator.new
      mock_model.queue_final_answer("done")

      builder = Smolagents.agent
                          .model { mock_model }
                          .tools(:final_answer)
                          .event_driven
                          .step_timeout(30)
                          .orchestrator(orchestrator)

      expect(builder.config[:event_driven]).to be true
      expect(builder.config[:step_timeout]).to eq(30)
      expect(builder.config[:orchestrator]).to eq(orchestrator)
      orchestrator.stop if orchestrator.running?
    end
  end
end
# rubocop:enable RSpec/DescribeClass
