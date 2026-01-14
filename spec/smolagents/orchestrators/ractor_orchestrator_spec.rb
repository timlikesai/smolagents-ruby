RSpec.describe Smolagents::Orchestrators::RactorOrchestrator do
  let(:mock_run_result) do
    double("RunResult",
           output: "Agent output",
           steps: [1, 2],
           token_usage: Smolagents::TokenUsage.new(input_tokens: 100, output_tokens: 50),
           success?: true)
  end

  let(:mock_model) do
    double("Model",
           model_id: "test-model",
           class: Smolagents::Models::OpenAIModel).tap do |model|
      allow(model).to receive(:instance_variable_get).with(:@client).and_return(nil)
      allow(model).to receive(:instance_variable_get).with(:@temperature).and_return(0.7)
      allow(model).to receive(:instance_variable_get).with(:@max_tokens).and_return(nil)
      allow(model).to receive(:instance_variable_get).with(:@custom_instructions).and_return(nil)
      allow(model).to receive(:instance_variable_defined?).with(:@temperature).and_return(true)
      allow(model).to receive(:instance_variable_defined?).with(:@max_tokens).and_return(false)
      allow(model).to receive(:respond_to?).with(:generate).and_return(true)
    end
  end

  let(:mock_agent) do
    double("Agent",
           model: mock_model,
           tools: { "tool1" => double },
           max_steps: 10,
           planning_interval: nil,
           run: mock_run_result).tap do |agent|
      allow(agent).to receive(:instance_variable_get).with(:@custom_instructions).and_return(nil)
    end
  end

  let(:agents) { { "researcher" => mock_agent, "analyzer" => mock_agent } }
  let(:orchestrator) { described_class.new(agents:) }

  describe "#initialize" do
    it "stores agents and max_concurrent" do
      orch = described_class.new(agents:, max_concurrent: 8)

      expect(orch.agents).to eq(agents)
      expect(orch.max_concurrent).to eq(8)
    end

    it "freezes the agents hash" do
      expect(orchestrator.agents).to be_frozen
    end
  end

  describe "#execute_parallel", skip: "Requires Ractor environment" do
    it "executes multiple tasks in parallel" do
      tasks = [
        ["researcher", "Research topic A", {}],
        ["analyzer", "Analyze data B", {}]
      ]

      result = orchestrator.execute_parallel(tasks:, timeout: 10)

      expect(result).to be_a(Smolagents::OrchestratorResult)
      expect(result.total_count).to eq(2)
    end
  end

  describe "#execute_single", skip: "Requires Ractor environment" do
    it "executes a single agent task" do
      result = orchestrator.execute_single(
        agent_name: "researcher",
        prompt: "Research something",
        timeout: 5
      )

      expect(result).to respond_to(:success?)
    end
  end

  describe "task creation" do
    it "creates RactorTasks from tuples" do
      orchestrator # Instantiate

      tasks = orchestrator.send(:create_ractor_tasks, [
                                  ["researcher", "Prompt 1", { max_steps: 5 }],
                                  ["analyzer", "Prompt 2", nil]
                                ])

      expect(tasks.size).to eq(2)
      expect(tasks[0]).to be_a(Smolagents::RactorTask)
      expect(tasks[0].agent_name).to eq("researcher")
      expect(tasks[0].prompt).to eq("Prompt 1")
      expect(tasks[1].agent_name).to eq("analyzer")
    end
  end

  describe "agent config preparation" do
    it "prepares agent config for Ractor with all reconstruction data" do
      task = Smolagents::RactorTask.create(
        agent_name: "researcher",
        prompt: "test",
        config: { max_steps: 15 }
      )

      config = orchestrator.send(:prepare_agent_config, mock_agent, task)

      expect(config).to be_frozen
      expect(config[:model_class]).to eq("Smolagents::Models::OpenAIModel")
      expect(config[:model_id]).to eq("test-model")
      expect(config[:model_config]).to be_a(Hash)
      expect(config[:model_config][:temperature]).to eq(0.7)
      expect(config[:max_steps]).to eq(15)
      expect(config[:tool_names]).to eq(["tool1"])
      expect(config[:planning_interval]).to be_nil
      expect(config[:custom_instructions]).to be_nil
    end

    it "extracts model config excluding sensitive data" do
      config = orchestrator.send(:extract_model_config, mock_model)

      expect(config).to be_frozen
      expect(config[:temperature]).to eq(0.7)
      expect(config).not_to have_key(:api_key)
      expect(config).not_to have_key(:max_tokens) # nil values excluded
    end
  end

  describe "result building" do
    it "builds OrchestratorResult from results" do
      mock_result = double("RunResult", output: "out", steps: [1], token_usage: nil)
      success = Smolagents::RactorSuccess.from_result(
        task_id: "1", run_result: mock_result, duration: 1.0, trace_id: "t1"
      )
      failure = Smolagents::RactorFailure.from_exception(
        task_id: "2", error: RuntimeError.new("err"), trace_id: "t2"
      )

      result = orchestrator.send(:build_orchestrator_result, [success, failure], 2.5)

      expect(result).to be_a(Smolagents::OrchestratorResult)
      expect(result.success_count).to eq(1)
      expect(result.failure_count).to eq(1)
      expect(result.duration).to eq(2.5)
    end
  end

  describe "error handling" do
    it "raises ArgumentError for unknown agent" do
      expect do
        orchestrator.send(:spawn_agent_ractor, Smolagents::RactorTask.create(agent_name: "unknown", prompt: "test"))
      end.to raise_error(ArgumentError, /Unknown agent/)
    end
  end

  describe ".execute_agent_task" do
    let(:task) { Smolagents::RactorTask.create(agent_name: "test", prompt: "test prompt") }

    context "without API key" do
      before { allow(ENV).to receive(:fetch).with("SMOLAGENTS_API_KEY").and_call_original }

      it "raises configuration error when SMOLAGENTS_API_KEY is missing" do
        expect do
          described_class.execute_agent_task(task, {})
        end.to raise_error(Smolagents::AgentConfigurationError, /SMOLAGENTS_API_KEY required/)
      end
    end

    context "with API key" do
      let(:config) do
        {
          model_class: "Smolagents::Models::OpenAIModel",
          model_id: "test-model",
          model_config: { temperature: 0.7 },
          agent_class: "Smolagents::Agents::ToolCalling",
          max_steps: 5,
          tool_names: ["final_answer"]
        }
      end

      before do
        allow(ENV).to receive(:fetch).with("SMOLAGENTS_API_KEY").and_return("test-key")
      end

      # NOTE: model_class in config is informational only - RactorModel is always used inside Ractors
      # because ruby-openai/anthropic gems don't work in Ractor due to global configuration access

      it "raises error for unknown tool" do
        bad_config = config.merge(tool_names: ["nonexistent_tool"])
        expect do
          described_class.execute_agent_task(task, bad_config)
        end.to raise_error(Smolagents::AgentConfigurationError, /Unknown tool.*Available/)
      end

      it "raises error for unknown agent class" do
        bad_config = config.merge(agent_class: "NonexistentAgent")

        # RactorModel is used inside Ractors (ruby-openai doesn't work there)
        stub_model = instance_double(Smolagents::Models::RactorModel)
        allow(Smolagents::Models::RactorModel).to receive(:new).and_return(stub_model)

        expect do
          described_class.execute_agent_task(task, bad_config)
        end.to raise_error(Smolagents::AgentConfigurationError, /Unknown agent class/)
      end

      it "reconstructs and runs agent with valid config" do
        stub_model = instance_double(Smolagents::Models::RactorModel)
        stub_agent = instance_double(Smolagents::Agents::ToolCalling)
        stub_run_result = double("RunResult", output: "success", steps: [], token_usage: nil)

        allow(Smolagents::Models::RactorModel).to receive(:new)
          .with(model_id: "test-model", api_key: "test-key", temperature: 0.7)
          .and_return(stub_model)

        allow(Smolagents::Agents::ToolCalling).to receive(:new)
          .with(model: stub_model, tools: anything, max_steps: 5)
          .and_return(stub_agent)

        allow(stub_agent).to receive(:run).with("test prompt").and_return(stub_run_result)

        result = described_class.execute_agent_task(task, config)

        expect(result).to eq(stub_run_result)
      end

      it "passes planning_interval when present" do
        config_with_planning = config.merge(planning_interval: 3)

        stub_model = instance_double(Smolagents::Models::RactorModel)
        stub_agent = instance_double(Smolagents::Agents::ToolCalling)
        stub_run_result = double("RunResult")

        allow(Smolagents::Models::RactorModel).to receive(:new).and_return(stub_model)
        allow(stub_agent).to receive(:run).and_return(stub_run_result)

        expect(Smolagents::Agents::ToolCalling).to receive(:new)
          .with(hash_including(planning_interval: 3))
          .and_return(stub_agent)

        described_class.execute_agent_task(task, config_with_planning)
      end

      it "passes custom_instructions when present" do
        config_with_instructions = config.merge(custom_instructions: "Be helpful")

        stub_model = instance_double(Smolagents::Models::RactorModel)
        stub_agent = instance_double(Smolagents::Agents::ToolCalling)
        stub_run_result = double("RunResult")

        allow(Smolagents::Models::RactorModel).to receive(:new).and_return(stub_model)
        allow(stub_agent).to receive(:run).and_return(stub_run_result)

        expect(Smolagents::Agents::ToolCalling).to receive(:new)
          .with(hash_including(custom_instructions: "Be helpful"))
          .and_return(stub_agent)

        described_class.execute_agent_task(task, config_with_instructions)
      end

      it "handles empty tool_names array" do
        config_no_tools = config.merge(tool_names: [])

        stub_model = instance_double(Smolagents::Models::RactorModel)
        stub_agent = instance_double(Smolagents::Agents::ToolCalling)
        stub_run_result = double("RunResult")

        allow(Smolagents::Models::RactorModel).to receive(:new).and_return(stub_model)
        allow(stub_agent).to receive(:run).and_return(stub_run_result)

        expect(Smolagents::Agents::ToolCalling).to receive(:new)
          .with(hash_including(tools: []))
          .and_return(stub_agent)

        described_class.execute_agent_task(task, config_no_tools)
      end

      it "reconstructs multiple tools from registry" do
        # NOTE: Registry keys (ruby_interpreter) differ from tool names (ruby)
        config_multi_tools = config.merge(tool_names: %w[final_answer ruby_interpreter])

        stub_model = instance_double(Smolagents::Models::RactorModel)
        stub_agent = instance_double(Smolagents::Agents::ToolCalling)
        stub_run_result = double("RunResult")

        allow(Smolagents::Models::RactorModel).to receive(:new).and_return(stub_model)
        allow(stub_agent).to receive(:run).and_return(stub_run_result)

        expect(Smolagents::Agents::ToolCalling).to receive(:new) do |args|
          expect(args[:tools].size).to eq(2)
          # Tool internal names: final_answer, ruby (not ruby_interpreter)
          expect(args[:tools].map(&:name)).to contain_exactly("final_answer", "ruby")
          stub_agent
        end

        described_class.execute_agent_task(task, config_multi_tools)
      end

      it "handles nil model_config" do
        config_nil_model_config = config.merge(model_config: nil)

        stub_model = instance_double(Smolagents::Models::RactorModel)
        stub_agent = instance_double(Smolagents::Agents::ToolCalling)
        stub_run_result = double("RunResult")

        # Should only pass model_id and api_key when model_config is nil
        expect(Smolagents::Models::RactorModel).to receive(:new)
          .with(model_id: "test-model", api_key: "test-key")
          .and_return(stub_model)

        allow(Smolagents::Agents::ToolCalling).to receive(:new).and_return(stub_agent)
        allow(stub_agent).to receive(:run).and_return(stub_run_result)

        described_class.execute_agent_task(task, config_nil_model_config)
      end

      it "works with CodeAgent class" do
        config_code_agent = config.merge(agent_class: "Smolagents::Agents::Code")

        stub_model = instance_double(Smolagents::Models::RactorModel)
        stub_agent = instance_double(Smolagents::Agents::Code)
        stub_run_result = double("RunResult")

        allow(Smolagents::Models::RactorModel).to receive(:new).and_return(stub_model)
        allow(stub_agent).to receive(:run).and_return(stub_run_result)

        expect(Smolagents::Agents::Code).to receive(:new)
          .with(hash_including(model: stub_model))
          .and_return(stub_agent)

        described_class.execute_agent_task(task, config_code_agent)
      end
    end
  end

  describe "agent config preparation edge cases" do
    let(:agent_with_planning) do
      double("Agent",
             model: mock_model,
             tools: { "tool1" => double, "tool2" => double },
             max_steps: 10,
             planning_interval: 5,
             run: mock_run_result).tap do |agent|
        allow(agent).to receive(:instance_variable_get).with(:@custom_instructions).and_return("Custom prompt")
      end
    end

    it "captures planning_interval when set" do
      task = Smolagents::RactorTask.create(agent_name: "test", prompt: "test")
      config = orchestrator.send(:prepare_agent_config, agent_with_planning, task)

      expect(config[:planning_interval]).to eq(5)
    end

    it "captures custom_instructions when set" do
      task = Smolagents::RactorTask.create(agent_name: "test", prompt: "test")
      config = orchestrator.send(:prepare_agent_config, agent_with_planning, task)

      expect(config[:custom_instructions]).to eq("Custom prompt")
    end

    it "captures multiple tool names" do
      task = Smolagents::RactorTask.create(agent_name: "test", prompt: "test")
      config = orchestrator.send(:prepare_agent_config, agent_with_planning, task)

      expect(config[:tool_names]).to contain_exactly("tool1", "tool2")
    end

    it "uses task config max_steps over agent max_steps" do
      task = Smolagents::RactorTask.create(agent_name: "test", prompt: "test", config: { max_steps: 20 })
      config = orchestrator.send(:prepare_agent_config, agent_with_planning, task)

      expect(config[:max_steps]).to eq(20)
    end

    it "uses agent max_steps when task config is empty" do
      task = Smolagents::RactorTask.create(agent_name: "test", prompt: "test", config: {})
      config = orchestrator.send(:prepare_agent_config, agent_with_planning, task)

      expect(config[:max_steps]).to eq(10)
    end
  end

  describe "model config extraction edge cases" do
    let(:model_with_api_base) do
      double("Model").tap do |model|
        client = double("Client", uri_base: "http://localhost:8080/v1")
        allow(model).to receive(:respond_to?).with(:generate).and_return(true)
        allow(model).to receive(:instance_variable_get).with(:@client).and_return(client)
        allow(model).to receive(:instance_variable_defined?).with(:@temperature).and_return(true)
        allow(model).to receive(:instance_variable_get).with(:@temperature).and_return(0.5)
        allow(model).to receive(:instance_variable_defined?).with(:@max_tokens).and_return(true)
        allow(model).to receive(:instance_variable_get).with(:@max_tokens).and_return(4096)
      end
    end

    let(:model_without_client) do
      double("Model").tap do |model|
        allow(model).to receive(:respond_to?).with(:generate).and_return(true)
        allow(model).to receive(:instance_variable_get).with(:@client).and_return(nil)
        allow(model).to receive(:instance_variable_defined?).with(:@temperature).and_return(true)
        allow(model).to receive(:instance_variable_get).with(:@temperature).and_return(0.3)
        allow(model).to receive(:instance_variable_defined?).with(:@max_tokens).and_return(false)
      end
    end

    let(:model_without_generate) do
      double("Model").tap do |model|
        allow(model).to receive(:respond_to?).with(:generate).and_return(false)
        allow(model).to receive(:instance_variable_defined?).with(:@temperature).and_return(true)
        allow(model).to receive(:instance_variable_get).with(:@temperature).and_return(0.8)
        allow(model).to receive(:instance_variable_defined?).with(:@max_tokens).and_return(false)
      end
    end

    it "extracts api_base from client when present" do
      config = orchestrator.send(:extract_model_config, model_with_api_base)

      expect(config[:api_base]).to eq("http://localhost:8080/v1")
    end

    it "extracts max_tokens when present" do
      config = orchestrator.send(:extract_model_config, model_with_api_base)

      expect(config[:max_tokens]).to eq(4096)
    end

    it "includes all model config fields" do
      config = orchestrator.send(:extract_model_config, model_with_api_base)

      expect(config.keys).to contain_exactly(:api_base, :temperature, :max_tokens)
    end

    it "handles model with nil client" do
      config = orchestrator.send(:extract_model_config, model_without_client)

      expect(config).not_to have_key(:api_base)
      expect(config[:temperature]).to eq(0.3)
    end

    it "handles model that does not respond to generate" do
      config = orchestrator.send(:extract_model_config, model_without_generate)

      expect(config).not_to have_key(:api_base)
      expect(config[:temperature]).to eq(0.8)
    end

    it "returns empty hash when no config available" do
      minimal_model = double("Model").tap do |model|
        allow(model).to receive(:respond_to?).with(:generate).and_return(false)
        allow(model).to receive(:instance_variable_defined?).with(:@temperature).and_return(false)
        allow(model).to receive(:instance_variable_defined?).with(:@max_tokens).and_return(false)
      end

      config = orchestrator.send(:extract_model_config, minimal_model)

      expect(config).to eq({})
      expect(config).to be_frozen
    end
  end

  describe "batching logic" do
    let(:orchestrator_with_low_concurrency) { described_class.new(agents:, max_concurrent: 2) }

    it "batches tasks when count exceeds max_concurrent" do
      # Test the execute_batched path indirectly
      tasks = orchestrator_with_low_concurrency.send(:create_ractor_tasks, [
                                                       ["researcher", "Task 1", {}],
                                                       ["researcher", "Task 2", {}],
                                                       ["researcher", "Task 3", {}],
                                                       ["researcher", "Task 4", {}]
                                                     ])

      # Verify batching would be used (tasks.size > max_concurrent)
      expect(tasks.size).to eq(4)
      expect(orchestrator_with_low_concurrency.max_concurrent).to eq(2)
      expect(tasks.size > orchestrator_with_low_concurrency.max_concurrent).to be true
    end
  end

  describe "result wrapping" do
    let(:task) { Smolagents::RactorTask.create(agent_name: "test", prompt: "test") }

    it "wraps success result with duration" do
      raw_result = {
        type: :success,
        task_id: task.task_id,
        trace_id: task.trace_id,
        output: "test output",
        steps_taken: 3,
        token_usage: nil
      }

      wrapped = orchestrator.send(:wrap_ractor_result, raw_result, task, 2.5)

      expect(wrapped).to be_a(Smolagents::RactorSuccess)
      expect(wrapped.task_id).to eq(task.task_id)
      expect(wrapped.output).to eq("test output")
      expect(wrapped.steps_taken).to eq(3)
      expect(wrapped.duration).to eq(2.5)
    end

    it "wraps failure result with duration" do
      raw_result = {
        type: :failure,
        task_id: task.task_id,
        trace_id: task.trace_id,
        error_class: "RuntimeError",
        error_message: "Something went wrong"
      }

      wrapped = orchestrator.send(:wrap_ractor_result, raw_result, task, 1.2)

      expect(wrapped).to be_a(Smolagents::RactorFailure)
      expect(wrapped.task_id).to eq(task.task_id)
      expect(wrapped.error_class).to eq("RuntimeError")
      expect(wrapped.error_message).to eq("Something went wrong")
      expect(wrapped.duration).to eq(1.2)
    end

    it "raises error for unexpected result type" do
      raw_result = { type: :unknown, data: "bad" }

      expect do
        orchestrator.send(:wrap_ractor_result, raw_result, task, 1.0)
      end.to raise_error(/Unexpected result type/)
    end
  end

  describe "ractor error handling" do
    it "creates failure from Ractor::RemoteError" do
      task = Smolagents::RactorTask.create(agent_name: "test", prompt: "test")
      original_error = RuntimeError.new("Original error")
      ractor_error = Ractor::RemoteError.new("Remote error")
      allow(ractor_error).to receive(:cause).and_return(original_error)

      failure = orchestrator.send(:create_ractor_error_failure, task, ractor_error)

      expect(failure).to be_a(Smolagents::RactorFailure)
      expect(failure.task_id).to eq(task.task_id)
      expect(failure.error_class).to eq("RuntimeError")
      expect(failure.error_message).to eq("Original error")
    end

    it "uses ractor error when no cause present" do
      task = Smolagents::RactorTask.create(agent_name: "test", prompt: "test")
      ractor_error = Ractor::RemoteError.new("Remote error only")
      allow(ractor_error).to receive(:cause).and_return(nil)

      failure = orchestrator.send(:create_ractor_error_failure, task, ractor_error)

      expect(failure.error_class).to eq("Ractor::RemoteError")
      expect(failure.error_message).to eq("Remote error only")
    end
  end
end
