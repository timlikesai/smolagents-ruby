# Adversarial integration tests for agent execution.
#
# These tests verify that agents handle common model failure modes gracefully:
# format drift (non-code responses), hallucinated tools, empty answers,
# and repetition loops. All tests use MockModel adversarial factories
# and are deterministic and fast (<120ms each).

RSpec.describe "Adversarial Agent Behavior", :integration do
  let(:mock_model) { Smolagents::Testing::MockModel.new }
  let(:event_queue) { Thread::Queue.new }

  def build_agent(**opts)
    agent = Smolagents.agent
                      .model { mock_model }
                      .max_steps(opts.fetch(:max_steps, 10))
    agent = agent.tools(*opts[:tools]) if opts[:tools]
    agent.build.tap do |a|
      a.connect_to(event_queue) if opts[:capture_events]
    end
  end

  def drain_events
    events = []
    events << event_queue.pop until event_queue.empty?
    events
  end

  # ============================================================
  # Format Drift Recovery
  # ============================================================

  describe "format drift recovery" do
    it "recovers from non-code model response via parse retry" do
      # First response is prose (triggers parse retry), second is proper code
      mock_model.queue_malformed("Let me think about this carefully...")
      mock_model.queue_final_answer("42")

      result = build_agent.run("What is the answer?")

      expect(result).to be_success
      expect(result.output).to eq("42")
    end

    it "recovers from hallucinated tool names" do
      # Model calls a tool that doesn't exist — execution error
      mock_model.queue_hallucinated_tool("nonexistent_tool(query: 'test')")
      mock_model.queue_evaluation_continue
      # Model sees error and provides final answer
      mock_model.queue_final_answer("recovered from bad tool call")

      result = build_agent.run("Use tools")

      expect(result).to be_success
      expect(result.output).to include("recovered")
    end

    it "rejects nil final_answer and continues" do
      # Model calls final_answer(answer: nil) — rejected by completion validation
      mock_model.queue_empty_final_answer
      mock_model.queue_evaluation_continue
      # Model provides real answer
      mock_model.queue_final_answer("proper answer")

      result = build_agent.run("Give me an answer")

      expect(result).to be_success
      expect(result.output).to eq("proper answer")
    end

    it "rejects empty final_answer and continues" do
      mock_model.queue_final_answer("")
      mock_model.queue_evaluation_continue
      mock_model.queue_final_answer("real answer")

      result = build_agent.run("Give me an answer")

      expect(result).to be_success
      expect(result.output).to eq("real answer")
    end

    it "handles empty model response" do
      # Empty response triggers parse failure → retry
      mock_model.queue_empty_response
      mock_model.queue_final_answer("recovered from empty")

      result = build_agent.run("Say something")

      expect(result).to be_success
      expect(result.output).to eq("recovered from empty")
    end

    it "handles text-only response via parse retry" do
      mock_model.queue_text_only("the sky is blue")
      mock_model.queue_final_answer("The sky is blue")

      result = build_agent.run("What color is the sky?")

      expect(result).to be_success
      expect(result.output).to eq("The sky is blue")
    end
  end

  # ============================================================
  # Multi-Error Recovery
  # ============================================================

  describe "multi-error recovery" do
    it "survives parse failure followed by execution error" do
      # Parse retry: malformed → code with undefined method
      mock_model.queue_malformed("thinking...")
      mock_model.queue_code_action("undefined_method_xyz()")
      mock_model.queue_evaluation_continue
      mock_model.queue_final_answer("recovered")

      result = build_agent.run("Complex task")

      expect(result).to be_success
      expect(result.output).to eq("recovered")
    end

    it "reaches max_steps gracefully after repeated failures" do
      5.times do
        mock_model.queue_code_action("undefined_method_xyz()")
        mock_model.queue_evaluation_continue
      end

      result = build_agent(max_steps: 3).run("Doomed task")

      expect(result.state).to eq(:max_steps_reached)
      expect(result.output).to be_nil
    end
  end

  # ============================================================
  # Conditional Response Patterns
  # ============================================================

  describe "conditional model responses" do
    it "model adapts response based on error observations" do
      # When model sees error feedback, it provides final answer
      mock_model.when_input_matches(/Error|error|undefined/) do
        'final_answer(answer: "adapted after error")'
      end
      # First step causes execution error
      mock_model.queue_code_action("undefined_xyz()")
      mock_model.queue_evaluation_continue

      result = build_agent.run("Try something")

      expect(result).to be_success
      expect(result.output).to eq("adapted after error")
    end

    it "uses default response as fallback" do
      mock_model.default_response('final_answer(answer: "default fallback")')

      result = build_agent.run("Any task")

      expect(result).to be_success
      expect(result.output).to eq("default fallback")
    end
  end

  # ============================================================
  # Repetition Detection and Recovery
  # ============================================================

  describe "repetition detection and recovery" do
    let(:search_tool) { build_test_tool(name: "search") }

    it "emits RepetitionDetected event after identical tool calls" do
      # Queue 3 identical search calls (window_size=3 triggers detection on 3rd)
      3.times do
        mock_model.queue_code_action('search(input: "same")')
        mock_model.queue_evaluation_continue
      end
      # After repetition guidance is injected, model recovers
      mock_model.default_response('final_answer(answer: "recovered")')

      agent = build_agent(tools: [search_tool], max_steps: 8, capture_events: true)
      agent.run("Find something")

      events = drain_events
      repetition_events = events.select { |e| e.is_a?(Smolagents::Events::RepetitionDetected) }

      expect(repetition_events).not_to be_empty
      expect(repetition_events.first.pattern).to eq(:tool_call)
      expect(repetition_events.first.count).to be >= 3
      expect(repetition_events.first.guidance).to include("search")
    end

    it "recovers from repetition loop and completes successfully" do
      # Queue 3 identical tool calls to trigger repetition detection
      3.times do
        mock_model.queue_code_action('search(input: "same")')
        mock_model.queue_evaluation_continue
      end
      # After repetition is detected, default_response provides recovery
      mock_model.default_response('final_answer(answer: "broke out of loop")')

      agent = build_agent(tools: [search_tool], max_steps: 8, capture_events: true)
      result = agent.run("Search for info")

      expect(result).to be_success
      expect(result.output).to eq("broke out of loop")

      # Verify repetition was detected before recovery
      events = drain_events
      repetition_events = events.select { |e| e.is_a?(Smolagents::Events::RepetitionDetected) }
      expect(repetition_events).not_to be_empty
    end

    it "includes guidance text in repetition event" do
      # Queue 3 identical code actions to trigger repetition
      3.times do
        mock_model.queue_code_action('search(input: "same query")')
        mock_model.queue_evaluation_continue
      end
      mock_model.default_response('final_answer(answer: "done")')

      agent = build_agent(tools: [search_tool], max_steps: 8, capture_events: true)
      agent.run("Repeat task")

      events = drain_events
      repetition_events = events.select { |e| e.is_a?(Smolagents::Events::RepetitionDetected) }

      expect(repetition_events).not_to be_empty
      expect(repetition_events.first.guidance).to be_a(String)
      expect(repetition_events.first.guidance.length).to be > 0
    end

    it "does not emit RepetitionDetected for varied tool calls" do
      # Each call has different arguments — no repetition
      mock_model.queue_code_action('search(input: "query one")')
      mock_model.queue_evaluation_continue
      mock_model.queue_code_action('search(input: "query two")')
      mock_model.queue_evaluation_continue
      mock_model.queue_code_action('search(input: "query three")')
      mock_model.queue_evaluation_continue
      mock_model.queue_final_answer("all done")

      agent = build_agent(tools: [search_tool], max_steps: 8, capture_events: true)
      result = agent.run("Search various things")

      events = drain_events
      repetition_events = events.select { |e| e.is_a?(Smolagents::Events::RepetitionDetected) }

      expect(result).to be_success
      expect(repetition_events).to be_empty
    end
  end
end
