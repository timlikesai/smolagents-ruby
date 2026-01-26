RSpec.describe "Spawn Integration", :integration do
  let(:mock_model) { instance_double(Smolagents::OpenAIModel) }
  let(:token_usage) { Smolagents::TokenUsage.new(input_tokens: 10, output_tokens: 5) }
  let(:mock_response) do
    Smolagents::ChatMessage.assistant(
      "```ruby\nfinal_answer(result: 'done')\n```",
      token_usage:
    )
  end

  before do
    allow(mock_model).to receive(:generate).and_return(mock_response)

    Smolagents.configure do |c|
      c.models do |m|
        m = m.register(:test_model, -> { mock_model })
        m
      end
    end
  end

  after { Smolagents.reset_configuration! }

  describe "agent with spawn_config" do
    it "stores spawn_config when using can_spawn DSL" do
      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(Smolagents::FinalAnswerTool.new)
                        .can_spawn(allow: [:test_model], tools: [:final_answer])
                        .build

      expect(agent.instance_variable_get(:@spawn_config)).not_to be_nil
      expect(agent.instance_variable_get(:@spawn_config).allowed_models).to eq([:test_model])
      expect(agent.instance_variable_get(:@spawn_config).allowed_tools).to eq([:final_answer])
    end

    it "defaults to :task_only context inheritance" do
      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(Smolagents::FinalAnswerTool.new)
                        .can_spawn(allow: [:test_model])
                        .build

      spawn_config = agent.instance_variable_get(:@spawn_config)
      expect(spawn_config.inherit_scope.level).to eq(:task_only)
    end

    it "allows configuring context inheritance" do
      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(Smolagents::FinalAnswerTool.new)
                        .can_spawn(allow: [:test_model], inherit: :observations)
                        .build

      spawn_config = agent.instance_variable_get(:@spawn_config)
      expect(spawn_config.inherit_scope.level).to eq(:observations)
    end

    it "defaults max_children to 3" do
      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(Smolagents::FinalAnswerTool.new)
                        .can_spawn(allow: [:test_model])
                        .build

      spawn_config = agent.instance_variable_get(:@spawn_config)
      expect(spawn_config.max_children).to eq(3)
    end

    it "allows configuring max_children" do
      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(Smolagents::FinalAnswerTool.new)
                        .can_spawn(allow: [:test_model], max_children: 5)
                        .build

      spawn_config = agent.instance_variable_get(:@spawn_config)
      expect(spawn_config.max_children).to eq(5)
    end
  end

  describe "SpawnConfig validation" do
    it "checks model allowance correctly" do
      config = Smolagents::Types::SpawnConfig.create(allow: %i[fast researcher])

      expect(config.model_allowed?(:fast)).to be true
      expect(config.model_allowed?(:researcher)).to be true
      expect(config.model_allowed?(:unknown)).to be false
    end

    it "allows any model when allow is empty" do
      config = Smolagents::Types::SpawnConfig.create(allow: [])

      # Empty allowed_models means any model is allowed
      expect(config.model_allowed?(:any_model)).to be true
      expect(config.allowed_models).to be_empty
    end

    it "checks tool allowance correctly" do
      config = Smolagents::Types::SpawnConfig.create(tools: %i[search final_answer])

      expect(config.tool_allowed?(:search)).to be true
      expect(config.tool_allowed?(:final_answer)).to be true
      expect(config.tool_allowed?(:unknown)).to be false
    end

    it "restricts tools when specified" do
      # NOTE: SpawnConfig requires explicit tool list - empty means no tools
      config = Smolagents::Types::SpawnConfig.create(tools: [:final_answer])

      expect(config.tool_allowed?(:final_answer)).to be true
      expect(config.tool_allowed?(:other_tool)).to be false
    end
  end

  describe "Spawn.create_spawn_function" do
    let(:spawn_config) do
      Smolagents::Types::SpawnConfig.create(
        allow: [:test_model],
        tools: [:final_answer],
        max_children: 2
      )
    end
    let(:parent_memory) { Smolagents::AgentMemory.new("Test prompt") }

    it "creates a callable spawn function" do
      spawn_fn = Smolagents::Runtime::Spawn.create_spawn_function(
        spawn_config:,
        parent_memory:,
        parent_model: mock_model
      )

      expect(spawn_fn).to respond_to(:call)
    end

    it "raises SpawnError when max_children exceeded" do
      spawn_fn = Smolagents::Runtime::Spawn.create_spawn_function(
        spawn_config:,
        parent_memory:,
        parent_model: mock_model
      )

      # First two spawns succeed
      expect { spawn_fn.call(task: "task 1") }.not_to raise_error
      expect { spawn_fn.call(task: "task 2") }.not_to raise_error

      # Third spawn exceeds limit
      expect { spawn_fn.call(task: "task 3") }.to raise_error(
        Smolagents::SpawnError,
        /Max children/
      )
    end

    it "raises SpawnError for disallowed model" do
      spawn_fn = Smolagents::Runtime::Spawn.create_spawn_function(
        spawn_config:,
        parent_memory:,
        parent_model: mock_model
      )

      expect { spawn_fn.call(model: :disallowed_model, task: "test") }.to raise_error(
        Smolagents::SpawnError,
        /not allowed/
      )
    end

    it "raises SpawnError for disallowed tool" do
      spawn_fn = Smolagents::Runtime::Spawn.create_spawn_function(
        spawn_config:,
        parent_memory:,
        parent_model: mock_model
      )

      expect { spawn_fn.call(tools: [:disallowed_tool], task: "test") }.to raise_error(
        Smolagents::SpawnError,
        /not allowed/
      )
    end

    it "uses parent model when no model specified" do
      spawn_fn = Smolagents::Runtime::Spawn.create_spawn_function(
        spawn_config:,
        parent_memory:,
        parent_model: mock_model
      )

      # This should work because it uses parent_model
      expect { spawn_fn.call(task: "test task") }.not_to raise_error
    end
  end

  describe "ContextScope integration" do
    let(:parent_memory) { Smolagents::AgentMemory.new("Test system prompt") }

    before do
      parent_memory.add_task("Parent task")
      parent_memory.add_step(
        Smolagents::ActionStep.new(
          step_number: 0,
          observations: "Some observation from parent",
          action_output: "output"
        )
      )
    end

    it "extracts task_only context" do
      scope = Smolagents::Types::ContextScope.create(:task_only)
      context = scope.extract_from(parent_memory, task: "Child task")

      expect(context[:task]).to eq("Child task")
      expect(context[:inherited_scope]).to eq(:task_only)
      expect(context[:parent_observations]).to be_nil
    end

    it "extracts observations context" do
      scope = Smolagents::Types::ContextScope.create(:observations)
      context = scope.extract_from(parent_memory, task: "Child task")

      expect(context[:task]).to eq("Child task")
      expect(context[:inherited_scope]).to eq(:observations)
      expect(context[:parent_observations]).to include("Some observation from parent")
    end
  end
end
