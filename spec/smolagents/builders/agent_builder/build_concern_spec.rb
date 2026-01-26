require "spec_helper"

RSpec.describe Smolagents::Builders::AgentBuildConcern do
  include_context "with mocked tools"
  include_context "with mocked model"

  let(:builder_class) { Smolagents::Builders::AgentBuilder }
  let(:builder) { builder_class.create }

  describe "#build" do
    context "when model is configured" do
      it "creates an Agent instance" do
        agent = builder.model { mock_model }.tools(mock_search_tool).build

        expect(agent).to be_a(Smolagents::Agents::Agent)
      end

      it "passes resolved model to agent" do
        agent = builder.model { mock_model }.tools(mock_search_tool).build

        expect(agent.model).to eq(mock_model)
      end

      it "passes resolved tools to agent" do
        agent = builder.model { mock_model }.tools(:google_search).build

        # mock_search_tool is returned when :google_search is resolved
        expect(agent.tools.keys).to include("test_search")
      end

      it "evaluates model block lazily at build time" do
        call_count = 0
        model_builder = builder.model do
          call_count += 1
          mock_model
        end

        expect(call_count).to eq(0)
        model_builder.tools(mock_search_tool).build
        expect(call_count).to eq(1)
      end

      it "registers event handlers on the built agent" do
        events_received = []
        agent = builder
                .model { mock_model }
                .tools(mock_search_tool)
                .on(:step_complete) { |e| events_received << e }
                .build

        event = Smolagents::Events::StepCompleted.create(step_number: 1, outcome: :success)
        agent.consume(event)

        expect(events_received.size).to eq(1)
      end

      it "passes executor to agent when configured" do
        executor = instance_double(Smolagents::RactorExecutor)
        allow(executor).to receive(:send_tools)

        agent = builder.model { mock_model }.executor(executor).build

        expect(agent.executor).to eq(executor)
      end

      it "passes logger to agent when configured" do
        logger = Logger.new(nil)
        agent = builder.model { mock_model }.logger(logger).build

        expect(agent.logger).to eq(logger)
      end

      it "passes managed_agents when configured" do
        sub_agent = instance_double(Smolagents::Agents::Agent)
        allow(sub_agent).to receive(:tools).and_return({ "test" => mock_search_tool })

        agent = builder
                .model { mock_model }
                .managed_agent(sub_agent, as: "helper")
                .build

        expect(agent.managed_agents.keys).to include("helper")
      end
    end

    context "when model is not configured" do
      it "raises ArgumentError" do
        expect { builder.tools(mock_search_tool).build }
          .to raise_error(ArgumentError, /Model required/)
      end
    end
  end

  describe "#config" do
    it "returns a copy of the configuration" do
      configured = builder.model { mock_model }.max_steps(10)
      config = configured.config

      expect(config).to be_a(Hash)
      expect(config[:max_steps]).to eq(10)
    end

    it "returns a duplicate (not the original)" do
      configured = builder.model { mock_model }
      config1 = configured.config
      config2 = configured.config

      expect(config1).not_to equal(config2)
      expect(config1).to eq(config2)
    end
  end

  describe "#inspect" do
    it "includes class name" do
      expect(builder.inspect).to include("AgentBuilder")
    end

    it "includes tool names" do
      configured = builder.tools(:google_search)

      expect(configured.inspect).to include("google_search")
    end

    it "includes tool instance names" do
      configured = builder.tools(mock_search_tool)

      expect(configured.inspect).to include("test_search")
    end

    it "shows handler count" do
      configured = builder
                   .on(:step_complete) { |_| :ok }
                   .on(:error) { |_| :err }

      expect(configured.inspect).to include("handlers=2")
    end
  end
end
