# Planning Integration Tests
#
# Tests that planning works correctly during agent execution.
# Verifies plans are generated at the correct intervals and influence execution.
#
RSpec.describe "Planning Integration" do
  let(:mock_token_usage) { Smolagents::TokenUsage.new(input_tokens: 100, output_tokens: 50) }
  let(:mock_executor) { instance_double(Smolagents::LocalRubyExecutor) }

  before do
    allow(mock_executor).to receive(:send_tools)
    allow(mock_executor).to receive(:send_variables)
    allow(mock_executor).to receive(:execute).and_return(
      Smolagents::Executors::Executor::ExecutionResult.success(output: "42", logs: "", is_final_answer: true)
    )
    allow(Smolagents::LocalRubyExecutor).to receive(:new).and_return(mock_executor)
  end

  describe "planning with agent execution" do
    let(:planning_response) do
      Smolagents::ChatMessage.assistant(
        "1. Analyze the task\n2. Execute the plan\n3. Verify the result",
        token_usage: mock_token_usage
      )
    end

    let(:action_response) do
      Smolagents::ChatMessage.assistant(
        <<~CODE,
          <code>
          final_answer("The answer is 42")
          </code>
        CODE
        token_usage: mock_token_usage
      )
    end

    let(:mock_model) do
      instance_double(Smolagents::Model, model_id: "test-model").tap do |m|
        # Smart mock: detect planning calls vs action calls by checking the system prompt
        allow(m).to receive(:generate) do |messages|
          system_msg = messages.find { |msg| msg.role == Smolagents::MessageRole::SYSTEM }
          if system_msg&.content&.include?("planning")
            planning_response
          else
            action_response
          end
        end
      end
    end

    it "generates initial plan before first action when planning_interval set" do
      agent = Smolagents::Agents::Agent.new(
        model: mock_model,
        tools: [Smolagents::FinalAnswerTool.new],
        planning_interval: 3,
        max_steps: 5
      )

      agent.run("Find the answer to life")

      # Verify planning occurred
      planning_steps = agent.memory.steps.select { |s| s.is_a?(Smolagents::PlanningStep) }
      expect(planning_steps.size).to be >= 1

      # First planning step should contain the plan
      first_plan = planning_steps.first
      expect(first_plan.plan).to include("Analyze the task")
    end

    it "does not generate plan when planning_interval is nil" do
      no_plan_model = instance_double(Smolagents::Model, model_id: "test-model")
      allow(no_plan_model).to receive(:generate).and_return(action_response)

      agent = Smolagents::Agents::Agent.new(
        model: no_plan_model,
        tools: [Smolagents::FinalAnswerTool.new],
        planning_interval: nil,
        max_steps: 5
      )

      agent.run("Simple task")

      planning_steps = agent.memory.steps.select { |s| s.is_a?(Smolagents::PlanningStep) }
      expect(planning_steps).to be_empty
    end

    it "stores plan_context with correct state after initial planning" do
      agent = Smolagents::Agents::Agent.new(
        model: mock_model,
        tools: [Smolagents::FinalAnswerTool.new],
        planning_interval: 3,
        max_steps: 5
      )

      agent.run("Test task")

      context = agent.send(:plan_context)
      expect(context).to be_initialized
      expect(context.plan).to include("Analyze")
    end
  end

  describe "planning interval mechanics" do
    let(:mock_model) do
      instance_double(Smolagents::Model, model_id: "test-model")
    end

    it "triggers planning at step 0 when interval is set" do
      # First call is planning, second is action
      call_count = 0
      allow(mock_model).to receive(:generate) do
        call_count += 1
        if call_count == 1
          # This is the planning call
          Smolagents::ChatMessage.assistant("Plan: Do the thing", token_usage: mock_token_usage)
        else
          # Action call - return final answer
          Smolagents::ChatMessage.assistant(
            '<code>final_answer("done")</code>',
            token_usage: mock_token_usage
          )
        end
      end

      agent = Smolagents::Agents::Agent.new(
        model: mock_model,
        tools: [Smolagents::FinalAnswerTool.new],
        planning_interval: 3,
        max_steps: 5
      )

      agent.run("Test")

      # Should have called generate at least twice (plan + action)
      expect(mock_model).to have_received(:generate).at_least(:twice)
    end
  end

  describe "builder DSL with planning" do
    let(:mock_model) { instance_double(Smolagents::Model, model_id: "test-model") }

    before do
      allow(mock_model).to receive(:generate).and_return(
        Smolagents::ChatMessage.assistant("Plan: Step 1", token_usage: mock_token_usage),
        Smolagents::ChatMessage.assistant('<code>final_answer("ok")</code>', token_usage: mock_token_usage)
      )
    end

    it "passes planning_interval through builder" do
      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(:final_answer)
                        .planning(interval: 5)
                        .max_steps(10)
                        .build

      expect(agent.planning_interval).to eq(5)
    end

    it "passes custom templates through builder" do
      custom_templates = {
        initial_plan: "Custom plan for: %<task>s with %<tools>s",
        planning_system: "You are a custom planner"
      }

      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(:final_answer)
                        .planning(interval: 3, templates: custom_templates)
                        .build

      expect(agent.planning_templates[:initial_plan]).to include("Custom plan")
    end

    it "builds functional agent with planning enabled" do
      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(:final_answer)
                        .planning(interval: 3)
                        .max_steps(5)
                        .build

      result = agent.run("Test task")

      expect(result).to be_success
    end
  end

  describe "plan context state transitions", skip: !ENV["LIVE_MODEL_TESTS"] do
    let(:lm_studio_url) { ENV.fetch("LM_STUDIO_URL", "http://localhost:1234/v1") }
    let(:model) do
      Smolagents::Models::OpenAIModel.new(
        model_id: "lfm2-8b-a1b",
        api_base: lm_studio_url,
        api_key: "not-needed"
      )
    end

    it "transitions from uninitialized to initial to active through execution" do
      agent = Smolagents.agent
                        .model { model }
                        .tools(:final_answer)
                        .planning(interval: 2)
                        .max_steps(6)
                        .build

      # Before run - uninitialized
      expect(agent.send(:plan_context).state).to eq(:uninitialized)

      agent.run("What is 2+2? Just answer with the number.")

      # After run - should be initialized (initial or active depending on steps taken)
      expect(agent.send(:plan_context)).to be_initialized
    end
  end
end
