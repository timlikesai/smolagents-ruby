# frozen_string_literal: true

RSpec.describe "Callback System Consolidation" do
  # Test that Monitorable and MultiStepAgent use the same CallbackRegistry implementation
  describe "Monitorable callbacks" do
    let(:test_class) do
      Class.new do
        include Smolagents::Concerns::Monitorable
      end
    end

    let(:instance) { test_class.new }

    it "uses CallbackRegistry internally" do
      expect(instance.send(:callbacks_registry)).to be_a(Smolagents::Monitoring::CallbackRegistry)
    end

    it "register_callback delegates to CallbackRegistry" do
      callback_called = false
      instance.register_callback(:test_event) { callback_called = true }

      instance.send(:callbacks_registry).trigger(:test_event)
      expect(callback_called).to be true
    end

    it "clear_callbacks delegates to CallbackRegistry" do
      callback_called = false
      instance.register_callback(:test_event) { callback_called = true }
      instance.clear_callbacks(:test_event)

      instance.send(:callbacks_registry).trigger(:test_event)
      expect(callback_called).to be false
    end

    it "supports Monitorable-specific events" do
      events_received = []

      instance.register_callback(:on_step_complete) { |name, _| events_received << [:complete, name] }
      instance.register_callback(:on_step_error) { |name, _, _| events_received << [:error, name] }
      instance.register_callback(:on_tokens_tracked) { |_| events_received << :tokens }

      # Trigger through monitor_step
      instance.monitor_step(:test_step) { "success" }

      # Trigger tokens_tracked
      usage = Smolagents::TokenUsage.new(input_tokens: 10, output_tokens: 5)
      instance.track_tokens(usage)

      expect(events_received).to include([:complete, :test_step])
      expect(events_received).to include(:tokens)
    end
  end

  describe "MultiStepAgent callbacks" do
    let(:mock_model) do
      response = Smolagents::ChatMessage.assistant("Final answer: test result")
      instance_double(Smolagents::Model, model_id: "test-model", generate: response)
    end

    let(:mock_tool) do
      Class.new(Smolagents::Tool) do
        self.tool_name = "test_tool"
        self.description = "Test tool"
        self.inputs = {}
        self.output_type = "string"

        def forward(**)
          "tool result"
        end
      end.new
    end

    let(:agent_class) do
      Class.new(Smolagents::MultiStepAgent) do
        def system_prompt
          "Test system prompt"
        end

        def step(task, step_number: 0)
          Smolagents::ActionStep.new(
            step_number: step_number,
            is_final_answer: true,
            action_output: "Final answer",
            timing: Smolagents::Timing.start_now.tap(&:stop),
            token_usage: Smolagents::TokenUsage.new(input_tokens: 10, output_tokens: 5)
          )
        end
      end
    end

    let(:agent) { agent_class.new(model: mock_model, tools: [mock_tool]) }

    it "uses the same CallbackRegistry as Monitorable" do
      expect(agent.send(:callbacks_registry)).to be_a(Smolagents::Monitoring::CallbackRegistry)
    end

    it "register_callback works for agent-level events" do
      events_received = []

      agent.register_callback(:step_start) { |num| events_received << [:start, num] }
      agent.register_callback(:step_complete) { |step, _| events_received << [:complete, step.step_number] }
      agent.register_callback(:task_complete) { |_| events_received << :task_complete }

      agent.run("test task")

      expect(events_received).to include([:start, 1])
      expect(events_received).to include([:complete, 1])
      expect(events_received).to include(:task_complete)
    end

    it "supports both Monitorable and agent-specific callbacks simultaneously" do
      all_events = []

      # Monitorable events
      agent.register_callback(:on_step_complete) { |name, _| all_events << [:monitorable, name] }

      # Agent-specific events
      agent.register_callback(:step_start) { |num| all_events << [:agent, :start, num] }
      agent.register_callback(:step_complete) { |step, _| all_events << [:agent, :complete, step.step_number] }

      agent.run("test task")

      # Should have both types of events
      expect(all_events).to include([:agent, :start, 1])
      expect(all_events).to include([:agent, :complete, 1])
      expect(all_events).to include([:monitorable, "step_1"])
    end

    it "clear_callbacks affects all callback types" do
      callback_called = false
      agent.register_callback(:step_start) { callback_called = true }

      agent.clear_callbacks(:step_start)
      agent.run("test task")

      expect(callback_called).to be false
    end
  end

  describe "Callback error handling" do
    let(:test_class) do
      Class.new do
        include Smolagents::Concerns::Monitorable
      end
    end

    let(:instance) { test_class.new }

    it "handles callback errors gracefully without stopping execution" do
      good_callback_called = false

      instance.register_callback(:on_step_complete) { raise "callback error" }
      instance.register_callback(:on_step_complete) { good_callback_called = true }

      expect do
        instance.monitor_step(:test) { "done" }
      end.not_to raise_error

      expect(good_callback_called).to be true
    end
  end
end
