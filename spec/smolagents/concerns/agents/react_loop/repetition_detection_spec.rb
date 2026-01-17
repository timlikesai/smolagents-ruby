RSpec.describe Smolagents::Concerns::ReActLoop::RepetitionDetection do
  # Create a test class that includes the concern
  let(:detector) do
    Class.new { include Smolagents::Concerns::ReActLoop::RepetitionDetection }.new
  end

  # Mock ActionStep structure for testing
  let(:step_class) do
    Struct.new(:tool_calls, :code_action, :observations, keyword_init: true)
  end

  let(:tool_call_class) do
    Struct.new(:name, :arguments, keyword_init: true)
  end

  describe "RepetitionResult" do
    let(:result_class) { described_class::RepetitionResult }

    describe ".none" do
      it "creates a result with no detection" do
        result = result_class.none
        expect(result.detected).to be false
        expect(result.pattern).to be_nil
        expect(result.count).to eq(0)
        expect(result.guidance).to be_nil
      end

      it "responds to none?" do
        result = result_class.none
        expect(result.none?).to be true
        expect(result.detected?).to be false
      end
    end

    describe ".detected" do
      it "creates a result with detection" do
        result = result_class.detected(pattern: :tool_call, count: 3, guidance: "Try something else")
        expect(result.detected).to be true
        expect(result.pattern).to eq(:tool_call)
        expect(result.count).to eq(3)
        expect(result.guidance).to eq("Try something else")
      end

      it "responds to detected?" do
        result = result_class.detected(pattern: :observation, count: 2, guidance: "Change approach")
        expect(result.none?).to be false
        expect(result.detected?).to be true
      end
    end

    describe "immutability" do
      it "is a Data type" do
        expect(result_class).to be < Data
      end
    end
  end

  describe "RepetitionConfig" do
    let(:config_class) { described_class::RepetitionConfig }

    describe ".default" do
      it "returns sensible defaults" do
        config = config_class.default
        expect(config.window_size).to eq(3)
        expect(config.similarity_threshold).to eq(0.9)
        expect(config.enabled).to be true
      end
    end

    describe "custom config" do
      it "accepts custom values" do
        config = config_class.new(window_size: 5, similarity_threshold: 0.8, enabled: false)
        expect(config.window_size).to eq(5)
        expect(config.similarity_threshold).to eq(0.8)
        expect(config.enabled).to be false
      end
    end
  end

  describe "#check_repetition" do
    let(:config) { described_class::RepetitionConfig.default }

    context "when disabled" do
      it "returns no detection" do
        disabled_config = described_class::RepetitionConfig.new(
          window_size: 3, similarity_threshold: 0.9, enabled: false
        )
        steps = [step_class.new, step_class.new, step_class.new]
        result = detector.check_repetition(steps, config: disabled_config)
        expect(result.none?).to be true
      end
    end

    context "with insufficient steps" do
      it "returns no detection when fewer than window_size" do
        steps = [step_class.new, step_class.new]
        result = detector.check_repetition(steps, config:)
        expect(result.none?).to be true
      end
    end

    context "with repeated tool calls" do
      it "detects identical tool calls" do
        tool_call = tool_call_class.new(name: "search", arguments: { query: "ruby" })
        steps = 3.times.map { step_class.new(tool_calls: [tool_call]) }

        result = detector.check_repetition(steps, config:)

        expect(result.detected?).to be true
        expect(result.pattern).to eq(:tool_call)
        expect(result.count).to eq(3)
        expect(result.guidance).to include("search")
        expect(result.guidance).to include("3 times")
      end

      it "does not detect different tool calls" do
        steps = [
          step_class.new(tool_calls: [tool_call_class.new(name: "search", arguments: { query: "ruby" })]),
          step_class.new(tool_calls: [tool_call_class.new(name: "search", arguments: { query: "python" })]),
          step_class.new(tool_calls: [tool_call_class.new(name: "visit", arguments: { url: "http://test.com" })])
        ]

        result = detector.check_repetition(steps, config:)
        expect(result.none?).to be true
      end

      it "normalizes argument comparison (case-insensitive, trimmed)" do
        steps = [
          step_class.new(tool_calls: [tool_call_class.new(name: "search", arguments: { query: "Ruby" })]),
          step_class.new(tool_calls: [tool_call_class.new(name: "search", arguments: { query: "ruby " })]),
          step_class.new(tool_calls: [tool_call_class.new(name: "search", arguments: { query: " RUBY" })])
        ]

        result = detector.check_repetition(steps, config:)
        expect(result.detected?).to be true
        expect(result.pattern).to eq(:tool_call)
      end
    end

    context "with repeated code actions" do
      it "detects identical code actions" do
        code = "search(query: 'test')"
        steps = 3.times.map { step_class.new(code_action: code) }

        result = detector.check_repetition(steps, config:)

        expect(result.detected?).to be true
        expect(result.pattern).to eq(:code_action)
        expect(result.count).to eq(3)
        expect(result.guidance).to include("same code")
      end

      it "normalizes whitespace in code comparison" do
        steps = [
          step_class.new(code_action: "search(query: 'test')"),
          step_class.new(code_action: "search(query:  'test')"),
          step_class.new(code_action: "search(query: 'test') ")
        ]

        result = detector.check_repetition(steps, config:)
        expect(result.detected?).to be true
        expect(result.pattern).to eq(:code_action)
      end

      it "does not detect different code actions" do
        steps = [
          step_class.new(code_action: "search(query: 'ruby')"),
          step_class.new(code_action: "search(query: 'python')"),
          step_class.new(code_action: "visit(url: 'http://test.com')")
        ]

        result = detector.check_repetition(steps, config:)
        expect(result.none?).to be true
      end
    end

    context "with repeated observations" do
      it "detects identical observations" do
        observation = "No results found for your query."
        steps = 3.times.map { step_class.new(observations: observation) }

        result = detector.check_repetition(steps, config:)

        expect(result.detected?).to be true
        expect(result.pattern).to eq(:observation)
        expect(result.count).to eq(3)
        expect(result.guidance).to include("same result")
      end

      it "detects similar observations above threshold" do
        steps = [
          step_class.new(observations: "No results found for your query."),
          step_class.new(observations: "No results found for your query!"),
          step_class.new(observations: "No results found for your query")
        ]

        result = detector.check_repetition(steps, config:)
        expect(result.detected?).to be true
        expect(result.pattern).to eq(:observation)
      end

      it "does not detect sufficiently different observations" do
        steps = [
          step_class.new(observations: "Found 5 results for Ruby programming"),
          step_class.new(observations: "Found 3 results for Python libraries"),
          step_class.new(observations: "Found 10 results for web frameworks")
        ]

        result = detector.check_repetition(steps, config:)
        expect(result.none?).to be true
      end
    end

    context "priority order" do
      it "detects tool_call before code_action" do
        tool_call = tool_call_class.new(name: "search", arguments: { query: "test" })
        steps = 3.times.map do
          step_class.new(tool_calls: [tool_call], code_action: "same_code()")
        end

        result = detector.check_repetition(steps, config:)
        expect(result.pattern).to eq(:tool_call)
      end

      it "detects code_action before observation" do
        steps = 3.times.map do
          step_class.new(code_action: "same_code()", observations: "Same output")
        end

        result = detector.check_repetition(steps, config:)
        expect(result.pattern).to eq(:code_action)
      end
    end
  end

  describe "#repetition_detected?" do
    let(:memory_class) { Struct.new(:action_steps, keyword_init: true) }

    it "uses memory's action_steps" do
      tool_call = tool_call_class.new(name: "search", arguments: { query: "test" })
      steps = 3.times.map { step_class.new(tool_calls: [tool_call]) }
      memory = memory_class.new(action_steps: steps)

      result = detector.repetition_detected?(memory)
      expect(result.detected?).to be true
    end

    it "returns none if memory doesn't respond to action_steps" do
      memory = Object.new
      result = detector.repetition_detected?(memory)
      expect(result.none?).to be true
    end
  end

  describe "string similarity (trigram-based)" do
    it "returns 1.0 for identical strings" do
      similarity = detector.send(:string_similarity, "hello world", "hello world")
      expect(similarity).to eq(1.0)
    end

    it "returns 0.0 for empty strings" do
      expect(detector.send(:string_similarity, "", "hello")).to eq(0.0)
      expect(detector.send(:string_similarity, "hello", "")).to eq(0.0)
    end

    it "returns high similarity for nearly identical strings" do
      similarity = detector.send(:string_similarity, "hello world", "hello world!")
      expect(similarity).to be > 0.8
    end

    it "returns low similarity for very different strings" do
      similarity = detector.send(:string_similarity, "hello world", "xyz abc 123")
      expect(similarity).to be < 0.3
    end
  end

  describe "guidance messages" do
    it "provides actionable guidance for tool_call repetition" do
      guidance = detector.send(:build_tool_call_guidance, "search", 3)
      expect(guidance).to include("search")
      expect(guidance).to include("3 times")
      expect(guidance).to include("different approach")
      expect(guidance).to include("final_answer")
    end

    it "provides actionable guidance for code_action repetition" do
      guidance = detector.send(:build_code_action_guidance, 4)
      expect(guidance).to include("same code")
      expect(guidance).to include("4 times")
      expect(guidance).to include("different algorithm")
      expect(guidance).to include("final_answer")
    end

    it "provides actionable guidance for observation repetition" do
      guidance = detector.send(:build_observation_guidance, 3)
      expect(guidance).to include("same result")
      expect(guidance).to include("3 times")
      expect(guidance).to include("different")
      expect(guidance).to include("final_answer")
    end
  end
end
