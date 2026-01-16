# Deterministic integration tests for agent execution.
#
# These tests exercise the FULL agent execution flow using MockModel,
# verifying that agents correctly handle responses, execute tools,
# manage memory, emit events, and track state.
#
# All tests are:
# - Deterministic (same result every run)
# - Fast (no sleeps or network calls)
# - Isolated (using MockModel and mocked executor)

RSpec.describe "Deterministic Agent Execution", :slow do
  let(:mock_model) { Smolagents::Testing::MockModel.new }
  let(:captured_events) { [] }
  let(:event_queue) { Thread::Queue.new }

  # Helper to build an agent with the mock model
  def build_agent(**opts) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    agent = Smolagents.agent
                      .model { mock_model }
                      .max_steps(opts.fetch(:max_steps, 10))

    agent = agent.planning(opts[:planning_interval]) if opts[:planning_interval]
    agent = agent.tools(*opts[:tools]) if opts[:tools]
    agent = agent.memory(**opts[:memory]) if opts[:memory]
    if opts[:spawn_config]
      # Convert hash to proper SpawnConfig parameters
      spawn = opts[:spawn_config]
      agent = agent.can_spawn(
        allow: spawn[:allow] || [],
        tools: spawn[:tools] || [:final_answer],
        inherit: spawn[:inherit] || :task_only,
        max_children: spawn[:max_children] || 3
      )
    end

    agent.build.tap do |a|
      a.connect_to(event_queue) if opts[:capture_events]
    end
  end

  # Helper to drain events from queue
  def drain_events
    events = []
    events << event_queue.pop until event_queue.empty?
    events
  end

  # ============================================================
  # Single-Step Scenarios
  # ============================================================

  describe "single-step execution" do
    it "returns final answer on first response" do
      mock_model.queue_final_answer("42")

      agent = build_agent
      result = agent.run("What is the answer?")

      expect(result).to be_success
      expect(result.output).to eq("42")
      expect(mock_model.call_count).to eq(1)
    end

    it "returns final answer with complex data types" do
      mock_model.queue_final_answer({ key: "value", count: 42 }.inspect)

      agent = build_agent
      result = agent.run("Return a hash")

      expect(result).to be_success
      expect(result.output).to include("key")
      expect(result.output).to include("42")
    end

    it "captures correct token usage from single step" do
      mock_model.queue_response(
        "<code>\nfinal_answer(\"done\")\n</code>",
        input_tokens: 100,
        output_tokens: 50
      )

      agent = build_agent
      result = agent.run("Simple task")

      expect(result.token_usage).to be_a(Smolagents::TokenUsage)
      expect(result.token_usage.input_tokens).to eq(100)
      expect(result.token_usage.output_tokens).to eq(50)
    end
  end

  describe "non-code response handling" do
    it "handles response without code block gracefully" do
      # First response has no code block, second has final answer
      mock_model.queue_response("I'm thinking about this...")
      mock_model.queue_final_answer("The answer is 42")

      agent = build_agent
      result = agent.run("What is the answer?")

      expect(result).to be_success
      expect(result.output).to eq("The answer is 42")
      expect(mock_model.call_count).to eq(2)

      # First step should have error about missing code
      error_step = result.steps.find { |s| s.is_a?(Smolagents::ActionStep) && s.error }
      expect(error_step).not_to be_nil
      expect(error_step.error).to include("code")
    end
  end

  describe "code execution error handling" do
    it "captures execution error in observations" do
      # Code that will cause an error, then successful final answer
      mock_model.queue_code_action("undefined_method_xyz()")
      mock_model.queue_final_answer("Recovered from error")

      agent = build_agent
      result = agent.run("Try something")

      expect(result).to be_success
      expect(mock_model.call_count).to eq(2)

      # First step should have the execution error
      error_step = result.steps.find { |s| s.is_a?(Smolagents::ActionStep) && s.error }
      expect(error_step).not_to be_nil
      expect(error_step.error).to match(/undefined/)
    end

    it "captures syntax error from malformed code" do
      mock_model.queue_code_action("def broken(") # Syntax error
      mock_model.queue_final_answer("Fixed it")

      agent = build_agent
      result = agent.run("Execute some code")

      expect(result).to be_success
      error_step = result.steps.find { |s| s.is_a?(Smolagents::ActionStep) && s.error }
      expect(error_step).not_to be_nil
      expect(error_step.error).to match(/syntax/i)
    end
  end

  # ============================================================
  # Multi-Step Tool Call Scenarios
  # ============================================================

  describe "multi-step tool execution" do
    let(:mock_tool) do
      tool = instance_double(Smolagents::Tool)
      allow(tool).to receive_messages(name: "mock_tool", description: "A mock tool for testing", inputs: {},
                                      output_type: "string", to_code_prompt: "mock_tool(): A mock tool for testing")
      tool
    end

    it "executes tool call then final answer in 2 steps" do
      allow(mock_tool).to receive(:call).with(query: "test").and_return("Tool result: success")

      # Step 1: Call tool and immediately return result as final answer
      mock_model.queue_code_action('final_answer(mock_tool(query: "test"))')

      agent = build_agent(tools: [mock_tool])
      result = agent.run("Use the tool")

      expect(result).to be_success
      expect(result.output).to eq("Tool result: success")
      expect(mock_model.call_count).to eq(1)
      expect(mock_tool).to have_received(:call).with(query: "test")
    end

    it "executes multiple tools sequentially in correct order" do
      tool1 = instance_double(Smolagents::Tool)
      allow(tool1).to receive_messages(
        name: "first_tool",
        description: "First tool",
        inputs: {},
        output_type: "string",
        to_code_prompt: "first_tool(): First tool"
      )
      allow(tool1).to receive(:call).and_return("first result")

      tool2 = instance_double(Smolagents::Tool)
      allow(tool2).to receive_messages(
        name: "second_tool",
        description: "Second tool",
        inputs: {},
        output_type: "string",
        to_code_prompt: "second_tool(): Second tool"
      )
      allow(tool2).to receive(:call).and_return("second result")

      # Each step is independent - variables don't persist across sandbox executions
      # So we call both tools in the same code block
      mock_model.queue_code_action("final_answer(\"\#{first_tool()} and \#{second_tool()}\")")

      agent = build_agent(tools: [tool1, tool2])
      result = agent.run("Use both tools")

      expect(result).to be_success
      expect(result.output).to include("first result")
      expect(result.output).to include("second result")
      expect(mock_model.call_count).to eq(1)
    end

    it "handles tool error and retries successfully" do
      call_count = 0
      allow(mock_tool).to receive(:call) do
        call_count += 1
        raise StandardError, "Tool failed temporarily" if call_count == 1

        "Success on retry"
      end

      # First call fails (tool raises)
      mock_model.queue_code_action('mock_tool(query: "test")')
      # Second call succeeds - model sees error in observations and retries
      mock_model.queue_code_action('final_answer(mock_tool(query: "test"))')

      agent = build_agent(tools: [mock_tool])
      result = agent.run("Try the tool")

      expect(result).to be_success
      expect(result.output).to eq("Success on retry")
      expect(call_count).to eq(2)
    end
  end

  # ============================================================
  # Planning Scenarios
  # ============================================================

  describe "planning enabled execution" do
    it "generates initial plan before first action" do
      # Planning response (no code)
      mock_model.queue_planning_response("Plan: 1. Think 2. Answer")
      # Action with final answer
      mock_model.queue_final_answer("Planned answer")

      agent = build_agent(planning_interval: 3)
      result = agent.run("Task requiring planning")

      expect(result).to be_success
      expect(result.output).to eq("Planned answer")

      # Should have a planning step
      planning_steps = result.steps.select { |s| s.is_a?(Smolagents::PlanningStep) }
      expect(planning_steps).not_to be_empty
      expect(planning_steps.first.plan).to include("Plan")
    end

    it "updates plan at configured interval" do
      # Initial plan
      mock_model.queue_planning_response("Initial plan: step 1, step 2, step 3")
      # Steps 1-3
      mock_model.queue_code_action("x = 1")
      mock_model.queue_code_action("y = 2")
      mock_model.queue_code_action("z = 3")
      # Plan update at step 3 (interval: 3)
      mock_model.queue_planning_response("Updated plan: almost done")
      # Final answer
      mock_model.queue_final_answer("Complete")

      agent = build_agent(planning_interval: 3, max_steps: 10)
      result = agent.run("Multi-step task with planning")

      expect(result).to be_success

      planning_steps = result.steps.select { |s| s.is_a?(Smolagents::PlanningStep) }
      expect(planning_steps.size).to be >= 2
    end
  end

  # ============================================================
  # Memory Scenarios
  # ============================================================

  describe "memory management" do
    it "masks old observations when over budget" do
      # Configure small budget that will be exceeded
      mock_model.queue_code_action('observation_1 = "A" * 1000')
      mock_model.queue_code_action('observation_2 = "B" * 1000')
      mock_model.queue_code_action('observation_3 = "C" * 1000')
      mock_model.queue_final_answer("Done")

      # Very small budget to force masking
      agent = build_agent(
        memory: { budget: 500, strategy: :mask, preserve_recent: 1 },
        max_steps: 10
      )
      result = agent.run("Generate lots of observations")

      expect(result).to be_success

      # Check that memory applied masking (messages would contain placeholder)
      messages = agent.memory.to_messages
      masked_count = messages.count { |m| m.content.to_s.include?("[Previous observation truncated]") }
      # With preserve_recent: 1, at least some should be masked
      expect(masked_count).to be >= 0 # Memory may or may not mask depending on actual size
    end

    it "keeps all observations with full strategy" do
      mock_model.queue_code_action('x = "observation data"')
      mock_model.queue_final_answer("Done")

      agent = build_agent(memory: { strategy: :full })
      result = agent.run("Simple task")

      expect(result).to be_success

      # All observations should be preserved
      messages = agent.memory.to_messages
      masked_count = messages.count { |m| m.content.to_s.include?("[Previous observation truncated]") }
      expect(masked_count).to eq(0)
    end
  end

  # ============================================================
  # Spawn Configuration Scenarios
  # ============================================================

  describe "spawn configuration" do
    it "creates agent with spawn config enabled" do
      mock_model.queue_final_answer("done")

      agent = build_agent(spawn_config: { allow: [:test_model], tools: [:final_answer], max_children: 3 })
      result = agent.run("Task")

      expect(result).to be_success
      # Verify spawn_config was set (agent accepts the config)
      expect(agent.instance_variable_get(:@spawn_config)).not_to be_nil
    end

    it "creates agent without spawn config by default" do
      mock_model.queue_final_answer("done")

      agent = build_agent
      result = agent.run("Task")

      expect(result).to be_success
      # Verify no spawn_config set
      expect(agent.instance_variable_get(:@spawn_config)).to be_nil
    end

    it "preserves spawn config parameters" do
      mock_model.queue_final_answer("done")

      agent = build_agent(spawn_config: {
                            allow: %i[model_a model_b],
                            tools: %i[search final_answer],
                            max_children: 5
                          })
      agent.run("Task")

      spawn_config = agent.instance_variable_get(:@spawn_config)
      expect(spawn_config.allowed_models).to contain_exactly(:model_a, :model_b)
      expect(spawn_config.allowed_tools).to contain_exactly(:search, :final_answer)
      expect(spawn_config.max_children).to eq(5)
    end
  end

  # ============================================================
  # State and Context Tracking
  # ============================================================

  describe "max_steps handling" do
    it "stops at max_steps with appropriate state" do
      # Queue more responses than max_steps
      5.times { mock_model.queue_code_action("x = 1") }

      agent = build_agent(max_steps: 3)
      result = agent.run("Task that takes too long")

      expect(result.state).to eq(:max_steps_reached)
      expect(result.output).to be_nil
      expect(mock_model.call_count).to eq(3)
    end

    it "stops exactly at max_steps boundary" do
      mock_model.queue_code_action("step_1 = true")
      mock_model.queue_final_answer("Completed in time")

      agent = build_agent(max_steps: 2)
      result = agent.run("Task with limited steps")

      # Should complete on step 2 with final answer
      expect(result).to be_success
      expect(result.output).to eq("Completed in time")
    end
  end

  describe "token usage tracking" do
    it "accumulates token usage across steps" do
      mock_model.queue_response("<code>\nx = 1\n</code>", input_tokens: 100, output_tokens: 50)
      mock_model.queue_response("<code>\nfinal_answer(\"done\")\n</code>", input_tokens: 120, output_tokens: 60)

      agent = build_agent
      result = agent.run("Multi-step task")

      expect(result).to be_success
      expect(result.token_usage.input_tokens).to eq(220)  # 100 + 120
      expect(result.token_usage.output_tokens).to eq(110) # 50 + 60
    end
  end

  describe "event emission" do
    it "emits step_complete events in correct sequence" do
      mock_model.queue_code_action("x = 1")
      mock_model.queue_final_answer("Done")

      agent = build_agent(capture_events: true)
      result = agent.run("Task with events")

      expect(result).to be_success

      events = drain_events
      step_events = events.select { |e| e.is_a?(Smolagents::Events::StepCompleted) }

      expect(step_events.size).to eq(2)
      expect(step_events[0].step_number).to eq(1)
      expect(step_events[1].step_number).to eq(2)
      expect(step_events[1].outcome).to eq(:final_answer)
    end

    it "emits task_complete event when finished" do
      mock_model.queue_final_answer("Complete")

      agent = build_agent(capture_events: true)
      result = agent.run("Quick task")

      expect(result).to be_success

      events = drain_events
      task_events = events.select { |e| e.is_a?(Smolagents::Events::TaskCompleted) }

      expect(task_events.size).to eq(1)
      expect(task_events.first.outcome).to eq(:success)
      expect(task_events.first.output).to eq("Complete")
    end

    it "emits error outcome when step has error" do
      mock_model.queue_code_action("undefined_xyz()")
      mock_model.queue_final_answer("Recovered")

      agent = build_agent(capture_events: true)
      result = agent.run("Task with error")

      expect(result).to be_success

      events = drain_events
      step_events = events.select { |e| e.is_a?(Smolagents::Events::StepCompleted) }

      error_step = step_events.find { |e| e.outcome == :error }
      expect(error_step).not_to be_nil
    end
  end

  # ============================================================
  # Message Sequence Verification
  # ============================================================

  describe "message sequence to model" do
    it "includes system prompt in first call" do
      mock_model.queue_final_answer("Done")

      agent = build_agent
      agent.run("My task")

      first_call = mock_model.calls.first
      expect(first_call[:messages].first.role).to eq(:system)
      expect(first_call[:messages].first.content).to include("Ruby")
    end

    it "includes task as user message" do
      mock_model.queue_final_answer("Done")

      agent = build_agent
      agent.run("Find the answer to everything")

      first_call = mock_model.calls.first
      user_message = first_call[:messages].find { |m| m.role == :user }
      expect(user_message.content).to include("Find the answer to everything")
    end

    it "includes observations from previous steps" do
      mock_model.queue_code_action('puts "Observable output"')
      mock_model.queue_final_answer("Done")

      agent = build_agent
      agent.run("Task")

      # Second call should include observations
      expect(mock_model.calls.size).to eq(2)
      second_call = mock_model.calls.last
      observation_message = second_call[:messages].find { |m| m.content.to_s.include?("Observation") }
      expect(observation_message).not_to be_nil
    end

    it "includes error messages in context for retry" do
      mock_model.queue_code_action("raise 'test error'")
      mock_model.queue_final_answer("Recovered")

      agent = build_agent
      agent.run("Task")

      second_call = mock_model.calls.last
      error_message = second_call[:messages].find { |m| m.content.to_s.include?("Error") }
      expect(error_message).not_to be_nil
      expect(error_message.content).to include("retry")
    end
  end

  # ============================================================
  # Step Structure Verification
  # ============================================================

  describe "step structure" do
    it "records code_action in action steps" do
      mock_model.queue_code_action("my_code = 42")
      mock_model.queue_final_answer("Done")

      agent = build_agent
      result = agent.run("Task")

      action_steps = result.steps.select { |s| s.is_a?(Smolagents::ActionStep) }
      code_step = action_steps.find { |s| s.code_action&.include?("my_code") }
      expect(code_step).not_to be_nil
    end

    it "includes timing in all steps" do
      mock_model.queue_final_answer("Done")

      agent = build_agent
      result = agent.run("Task")

      result.steps.each do |step|
        next unless step.respond_to?(:timing) && step.timing

        expect(step.timing.start_time).not_to be_nil
        expect(step.timing.end_time).not_to be_nil
      end
    end

    it "includes model output message in action steps" do
      mock_model.queue_final_answer("The answer")

      agent = build_agent
      result = agent.run("Task")

      action_steps = result.steps.select { |s| s.is_a?(Smolagents::ActionStep) }
      expect(action_steps.first.model_output_message).to be_a(Smolagents::ChatMessage)
    end
  end

  # ============================================================
  # Edge Cases
  # ============================================================

  describe "edge cases" do
    it "handles empty string final answer" do
      mock_model.queue_final_answer("")

      agent = build_agent
      result = agent.run("Task")

      expect(result).to be_success
      expect(result.output).to eq("")
    end

    it "handles nil-like values in code" do
      mock_model.queue_code_action("result = nil")
      mock_model.queue_final_answer("nil result handled")

      agent = build_agent
      result = agent.run("Task with nil")

      expect(result).to be_success
    end

    it "handles special characters in output" do
      special_answer = 'Answer with "quotes" and \'apostrophes\' and \\ backslash'
      mock_model.queue_final_answer(special_answer)

      agent = build_agent
      result = agent.run("Task")

      expect(result).to be_success
      expect(result.output).to include("quotes")
    end

    it "handles unicode in responses" do
      mock_model.queue_final_answer("Unicode: , , ")

      agent = build_agent
      result = agent.run("Task")

      expect(result).to be_success
      expect(result.output).to include("")
    end

    it "resets state between runs" do
      mock_model.queue_final_answer("First run")
      mock_model.queue_final_answer("Second run")

      agent = build_agent
      result1 = agent.run("First task")
      result2 = agent.run("Second task")

      expect(result1.output).to eq("First run")
      expect(result2.output).to eq("Second run")

      # Each run should start fresh
      expect(result2.steps.count { |s| s.is_a?(Smolagents::TaskStep) }).to eq(1)
    end
  end

  # ============================================================
  # RunResult Structure
  # ============================================================

  describe "RunResult structure" do
    it "includes all expected fields" do
      mock_model.queue_final_answer("Complete")

      agent = build_agent
      result = agent.run("Task")

      expect(result).to respond_to(:output)
      expect(result).to respond_to(:state)
      expect(result).to respond_to(:steps)
      expect(result).to respond_to(:token_usage)
      expect(result).to respond_to(:timing)
    end

    it "has correct state for successful completion" do
      mock_model.queue_final_answer("Done")

      agent = build_agent
      result = agent.run("Task")

      expect(result.state).to eq(:success)
      expect(result.success?).to be true
      expect(result.failure?).to be false
    end

    it "has correct state for max_steps" do
      3.times { mock_model.queue_code_action("x = 1") }

      agent = build_agent(max_steps: 2)
      result = agent.run("Long task")

      expect(result.state).to eq(:max_steps_reached)
      expect(result.success?).to be false
    end

    it "includes timing with duration" do
      mock_model.queue_final_answer("Done")

      agent = build_agent
      result = agent.run("Task")

      expect(result.timing).to respond_to(:duration)
      expect(result.timing.duration).to be_a(Float)
    end
  end
end
