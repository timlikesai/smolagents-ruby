RSpec.describe Smolagents::Concerns::ReActLoop::Repetition::Detectors do
  # Include all required modules for Detectors to work
  let(:detector) do
    Class.new do
      include Smolagents::Concerns::ReActLoop::Repetition::Similarity
      include Smolagents::Concerns::ReActLoop::Repetition::Guidance
      include Smolagents::Concerns::ReActLoop::Repetition::Detectors

      # Make RepetitionResult accessible
      RepetitionResult = Smolagents::Concerns::ReActLoop::Repetition::RepetitionResult
    end.new
  end

  # Mock ActionStep structure for testing
  let(:step_class) do
    # rubocop:disable Smolagents/PreferDataDefine -- mocking mutable step objects
    Struct.new(:tool_calls, :code_action, :observations, keyword_init: true)
    # rubocop:enable Smolagents/PreferDataDefine
  end

  let(:tool_call_class) { Data.define(:name, :arguments) }

  describe ".provided_methods" do
    it "documents available methods" do
      methods = described_class.provided_methods
      expect(methods).to include(
        :detect_tool_call_repetition,
        :detect_code_action_repetition,
        :detect_observation_repetition
      )
    end
  end

  describe "#detect_tool_call_repetition" do
    it "detects identical tool calls" do
      tool_call = tool_call_class.new(name: "search", arguments: { query: "ruby" })
      steps = Array.new(3) { step_class.new(tool_calls: [tool_call]) }

      result = detector.send(:detect_tool_call_repetition, steps)

      expect(result).not_to be_nil
      expect(result.pattern).to eq(:tool_call)
      expect(result.count).to eq(3)
      expect(result.guidance).to include("search")
    end

    it "returns nil for different tool calls" do
      steps = [
        step_class.new(tool_calls: [tool_call_class.new(name: "search", arguments: { query: "ruby" })]),
        step_class.new(tool_calls: [tool_call_class.new(name: "search", arguments: { query: "python" })]),
        step_class.new(tool_calls: [tool_call_class.new(name: "visit", arguments: { url: "http://test.com" })])
      ]

      result = detector.send(:detect_tool_call_repetition, steps)
      expect(result).to be_nil
    end

    it "normalizes argument comparison (case-insensitive, trimmed)" do
      steps = [
        step_class.new(tool_calls: [tool_call_class.new(name: "search", arguments: { query: "Ruby" })]),
        step_class.new(tool_calls: [tool_call_class.new(name: "search", arguments: { query: "ruby " })]),
        step_class.new(tool_calls: [tool_call_class.new(name: "search", arguments: { query: " RUBY" })])
      ]

      result = detector.send(:detect_tool_call_repetition, steps)
      expect(result).not_to be_nil
      expect(result.pattern).to eq(:tool_call)
    end

    it "returns nil for steps without tool calls" do
      steps = Array.new(3) { step_class.new(code_action: "some_code()") }
      result = detector.send(:detect_tool_call_repetition, steps)
      expect(result).to be_nil
    end
  end

  describe "#detect_code_action_repetition" do
    it "detects identical code actions" do
      code = "search(query: 'test')"
      steps = Array.new(3) { step_class.new(code_action: code) }

      result = detector.send(:detect_code_action_repetition, steps)

      expect(result).not_to be_nil
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

      result = detector.send(:detect_code_action_repetition, steps)
      expect(result).not_to be_nil
      expect(result.pattern).to eq(:code_action)
    end

    it "returns nil for different code actions" do
      steps = [
        step_class.new(code_action: "search(query: 'ruby')"),
        step_class.new(code_action: "search(query: 'python')"),
        step_class.new(code_action: "visit(url: 'http://test.com')")
      ]

      result = detector.send(:detect_code_action_repetition, steps)
      expect(result).to be_nil
    end
  end

  describe "#detect_observation_repetition" do
    it "detects identical observations" do
      observation = "No results found for your query."
      steps = Array.new(3) { step_class.new(observations: observation) }

      result = detector.send(:detect_observation_repetition, steps, 0.9)

      expect(result).not_to be_nil
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

      result = detector.send(:detect_observation_repetition, steps, 0.9)
      expect(result).not_to be_nil
      expect(result.pattern).to eq(:observation)
    end

    it "returns nil for sufficiently different observations" do
      steps = [
        step_class.new(observations: "Found 5 results for Ruby programming"),
        step_class.new(observations: "Found 3 results for Python libraries"),
        step_class.new(observations: "Found 10 results for web frameworks")
      ]

      result = detector.send(:detect_observation_repetition, steps, 0.9)
      expect(result).to be_nil
    end

    it "returns nil with fewer than 2 observations" do
      steps = [step_class.new(observations: "Single observation")]
      result = detector.send(:detect_observation_repetition, steps, 0.9)
      expect(result).to be_nil
    end
  end

  describe "#normalize_arguments" do
    it "converts values to lowercase and trims whitespace" do
      args = { query: " Ruby ", name: "HELLO" }
      result = detector.send(:normalize_arguments, args)
      expect(result).to eq({ query: "ruby", name: "hello" })
    end

    it "returns empty hash for nil" do
      expect(detector.send(:normalize_arguments, nil)).to eq({})
    end
  end

  describe "#normalize_code" do
    it "collapses multiple whitespace to single space" do
      code = "search(query:   'test')"
      result = detector.send(:normalize_code, code)
      expect(result).to eq("search(query: 'test')")
    end

    it "strips leading and trailing whitespace" do
      code = "  search()  "
      result = detector.send(:normalize_code, code)
      expect(result).to eq("search()")
    end
  end
end
