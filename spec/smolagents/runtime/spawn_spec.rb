RSpec.describe Smolagents::Runtime::Spawn do
  let(:mock_model) { instance_double(Smolagents::OpenAIModel) }
  let(:mock_memory) { instance_double(Smolagents::Runtime::AgentMemory) }
  let(:spawn_config) do
    Smolagents::Types::SpawnConfig.create(
      allow: [:test_model],
      tools: [:final_answer],
      inherit: :task_only,
      max_children: 3
    )
  end

  before do
    allow(mock_memory).to receive(:action_steps).and_return([])
    allow(Smolagents).to receive(:get_model).with(:test_model).and_return(mock_model)
    allow(Smolagents::Tools).to receive(:get).with("final_answer").and_return(Smolagents::FinalAnswerTool.new)
  end

  describe ".create_spawn_function" do
    it "creates a callable spawn function" do
      spawn_fn = described_class.create_spawn_function(
        spawn_config:,
        parent_memory: mock_memory,
        parent_model: mock_model
      )
      expect(spawn_fn).to respond_to(:call)
    end

    it "raises SpawnError when spawn_config is nil" do
      spawn_fn = described_class.create_spawn_function(
        spawn_config: nil,
        parent_memory: mock_memory,
        parent_model: mock_model
      )
      expect { spawn_fn.call(task: "test") }.to raise_error(Smolagents::SpawnError)
    end

    it "raises SpawnError when max_children exceeded" do
      spawn_fn = described_class.create_spawn_function(
        spawn_config:,
        parent_memory: mock_memory,
        parent_model: mock_model
      )

      # Stub Agent.new to return a mock that responds to run
      mock_agent = instance_double(Smolagents::Agents::Agent)
      allow(mock_agent).to receive(:run).and_return(double(output: "result"))
      allow(Smolagents::Agents::Agent).to receive(:new).and_return(mock_agent)

      3.times { spawn_fn.call(model: :test_model, task: "test") }
      expect { spawn_fn.call(model: :test_model, task: "test") }.to raise_error(Smolagents::SpawnError, /Max children/)
    end

    it "raises SpawnError for disallowed model" do
      spawn_fn = described_class.create_spawn_function(
        spawn_config:,
        parent_memory: mock_memory,
        parent_model: mock_model
      )
      expect { spawn_fn.call(model: :unauthorized) }.to raise_error(Smolagents::SpawnError, /not allowed/)
    end
  end
end
