require "smolagents/concerns/agents/react_loop/setup"

RSpec.describe Smolagents::Concerns::ReActLoop::Setup do
  describe "#setup_agent" do
    let(:test_class) do
      Class.new do
        include Smolagents::Concerns::ReActLoop::Setup

        attr_accessor :model, :tools, :max_steps, :logger, :state, :spawn_config,
                      :memory, :custom_instructions, :evaluation_enabled

        def system_prompt
          "System prompt"
        end

        def setup_managed_agents(_agents); end

        def tools_with_managed_agents(tools)
          tools
        end

        def initialize_planning(planning_interval:, planning_templates:); end
      end
    end

    let(:instance) { test_class.new }
    let(:mock_model) { double("model") }
    let(:mock_tool) { double("tool", name: "search") }

    let(:config) do
      double(
        "config",
        model: mock_model,
        tools: [mock_tool],
        max_steps: 10,
        logger: nil,
        custom_instructions: nil,
        spawn_config: nil,
        planning_interval: nil,
        planning_templates: nil,
        evaluation_enabled: false,
        managed_agents: []
      )
    end

    it "initializes agent with config" do
      instance.setup_agent(config)

      expect(instance.model).to eq(mock_model)
      expect(instance.max_steps).to eq(10)
    end

    it "accepts SetupConfig object" do
      expect { instance.setup_agent(config) }.not_to raise_error
    end

    it "configures tools" do
      instance.setup_agent(config)

      expect(instance.tools).not_to be_nil
    end

    it "initializes state hash" do
      instance.setup_agent(config)

      expect(instance.state).to eq({})
    end
  end

  describe "private helper methods" do
    let(:test_class) do
      Class.new do
        include Smolagents::Concerns::ReActLoop::Setup

        attr_accessor :model, :tools, :max_steps, :logger, :state, :spawn_config,
                      :memory, :custom_instructions, :task_images, :evaluation_enabled

        def system_prompt
          "System prompt"
        end

        def setup_managed_agents(_agents); end

        def tools_with_managed_agents(tools)
          tools
        end

        def emitting?
          false
        end
      end
    end

    let(:instance) { test_class.new }

    describe "#reset_state" do
      it "resets memory and state" do
        instance.instance_variable_set(:@memory, double("memory", reset: nil))
        instance.instance_variable_set(:@state, { foo: "bar" })

        instance.send(:reset_state)

        expect(instance.state).to eq({})
      end
    end

    describe "#prepare_run" do
      it "resets state when reset is true" do
        instance.instance_variable_set(:@memory, double("memory", reset: nil))
        instance.instance_variable_set(:@state, { foo: "bar" })

        instance.send(:prepare_run, true, nil)

        expect(instance.state).to eq({})
      end

      it "sets task_images when provided" do
        instance.instance_variable_set(:@memory, double("memory", reset: nil))
        instance.instance_variable_set(:@state, {})

        images = ["image1.png"]
        instance.send(:prepare_run, false, images)

        expect(instance.task_images).to eq(images)
      end
    end

    describe "#should_create_root_goal?" do
      it "returns false when create_goal_from_task is not available" do
        result = instance.send(:should_create_root_goal?)

        expect(result).to be false
      end
    end
  end

  describe "agent configuration" do
    let(:test_class) do
      Class.new do
        include Smolagents::Concerns::ReActLoop::Setup

        attr_accessor :model, :tools, :max_steps, :logger, :state, :spawn_config,
                      :memory, :custom_instructions, :evaluation_enabled

        def system_prompt
          "System prompt"
        end

        def setup_managed_agents(_agents); end

        def tools_with_managed_agents(tools)
          tools
        end

        def initialize_planning(planning_interval:, planning_templates:); end
      end
    end

    let(:instance) { test_class.new }
    let(:mock_model) { double("model") }

    let(:config) do
      double(
        "config",
        model: mock_model,
        tools: [],
        max_steps: 20,
        logger: nil,
        custom_instructions: nil,
        spawn_config: nil,
        planning_interval: nil,
        planning_templates: nil,
        evaluation_enabled: false,
        managed_agents: []
      )
    end

    it "sets up complete agent state" do
      instance.setup_agent(config)

      expect(instance.model).not_to be_nil
      expect(instance.max_steps).to eq(20)
    end

    it "supports custom configuration" do
      custom_config = double(
        "config",
        model: mock_model,
        tools: [double("tool")],
        max_steps: 5,
        logger: nil,
        custom_instructions: nil,
        spawn_config: nil,
        planning_interval: nil,
        planning_templates: nil,
        evaluation_enabled: false,
        managed_agents: []
      )

      instance.setup_agent(custom_config)

      expect(instance.max_steps).to eq(5)
    end
  end
end
