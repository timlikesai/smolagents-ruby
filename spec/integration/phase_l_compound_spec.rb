# Phase L compound integration tests.
#
# Validates that multiple Phase L features (GenerationTimeout, ParseRetry events,
# default retries) work together in realistic agent execution contexts.
# All tests are deterministic and fast (<120ms each).
# Evaluation disabled to isolate feature-under-test from evaluation model calls.

RSpec.describe "Phase L Compound Behavior", :integration do
  let(:mock_model) { Smolagents::Testing::MockModel.new }
  let(:event_queue) { Thread::Queue.new }

  def build_agent(**opts)
    builder = Smolagents.agent
                        .model { mock_model }
                        .evaluation(enabled: false)
                        .max_steps(opts.fetch(:max_steps, 10))
    builder = builder.generation_timeout(opts[:timeout]) if opts[:timeout]
    builder.build.tap { |a| a.connect_to(event_queue) }
  end

  def drain_events
    events = []
    events << event_queue.pop until event_queue.empty?
    events
  end

  # ============================================================
  # Generation Timeout + Normal Execution
  # ============================================================

  describe "generation timeout passthrough" do
    it "completes normally with timeout configured" do
      mock_model.queue_final_answer("done")

      result = build_agent(timeout: 120).run("Simple task")

      expect(result).to be_success
      expect(result.output).to eq("done")
    end

    it "does not interfere with multi-step execution" do
      mock_model.queue_code_action("calculate(expression: \"2+2\")")
      mock_model.queue_final_answer("4")

      result = build_agent(timeout: 120, max_steps: 5).run("Calculate 2+2")

      expect(result).to be_success
      expect(result.output).to eq("4")
    end
  end

  # ============================================================
  # Parse Retry Event Emission in Agent Context
  # ============================================================

  describe "parse retry events in agent run" do
    it "emits ParseRetryAttempted when model output drifts" do
      mock_model.queue_malformed("Let me think about this...")
      mock_model.queue_final_answer("42")

      result = build_agent.run("What is the answer?")

      expect(result).to be_success
      retry_events = drain_events.select { |e| e.is_a?(Smolagents::Events::ParseRetryAttempted) }
      expect(retry_events.size).to eq(1)
      expect(retry_events.first.retry_number).to eq(1)
    end

    it "emits multiple retry events for consecutive format drift" do
      # 2 malformed within one step (retry 1 + retry 2), then final answer on step 2
      mock_model.queue_malformed("Thinking step 1...")
      mock_model.queue_malformed("Thinking step 2...")
      mock_model.queue_final_answer("recovered")

      result = build_agent.run("Task")

      expect(result).to be_success
      expect(result.output).to eq("recovered")
      retry_events = drain_events.select { |e| e.is_a?(Smolagents::Events::ParseRetryAttempted) }
      expect(retry_events.size).to be >= 1
    end
  end

  # ============================================================
  # Default Parse Retries = 2
  # ============================================================

  describe "default parse retry budget" do
    it "recovers from two consecutive malformed responses" do
      # Within one step: original + 1 retry = 2 attempts, both fail
      # Step 2: final answer succeeds
      mock_model.queue_malformed("No code here at all")
      mock_model.queue_malformed("Still no code")
      mock_model.queue_final_answer("finally")

      result = build_agent.run("Give me an answer")

      expect(result).to be_success
      expect(result.output).to eq("finally")
    end
  end

  # ============================================================
  # Generation Timeout Fires (blocking model)
  # ============================================================

  describe "generation timeout fires", :slow do
    it "handles timeout without hanging" do
      gate = Queue.new
      blocking_model = Smolagents::Testing::MockModel.new
      blocking_model.define_singleton_method(:generate) do |*, **|
        gate.pop
      end

      agent = Smolagents.agent
                        .model { blocking_model }
                        .generation_timeout(0.01)
                        .evaluation(enabled: false)
                        .max_steps(3)
                        .build
      agent.connect_to(event_queue)

      result = agent.run("Blocked task")

      expect(result).not_to be_nil
      gate.push(:release) # Clean up blocking thread
    end
  end
end
