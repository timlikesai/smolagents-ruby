RSpec.describe Smolagents::Concerns::ReActLoop::Repetition do
  let(:test_class) do
    Class.new { include Smolagents::Concerns::ReActLoop::Repetition }
  end

  let(:instance) { test_class.new }

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
        :check_repetition,
        :string_similarity,
        :trigrams
      )
    end
  end

  describe "GUIDANCE_TEMPLATES" do
    it "defines templates for all repetition types" do
      expect(described_class::GUIDANCE_TEMPLATES).to include(:tool_call, :code_action, :observation)
    end
  end

  # === Similarity Tests ===

  describe "#string_similarity" do
    it "returns 1.0 for identical strings" do
      similarity = instance.send(:string_similarity, "hello world", "hello world")
      expect(similarity).to eq(1.0)
    end

    it "returns 0.0 for empty first string" do
      expect(instance.send(:string_similarity, "", "hello")).to eq(0.0)
    end

    it "returns 0.0 for empty second string" do
      expect(instance.send(:string_similarity, "hello", "")).to eq(0.0)
    end

    it "returns high similarity for nearly identical strings" do
      similarity = instance.send(:string_similarity, "hello world", "hello world!")
      expect(similarity).to be > 0.8
    end

    it "returns low similarity for very different strings" do
      similarity = instance.send(:string_similarity, "hello world", "xyz abc 123")
      expect(similarity).to be < 0.3
    end

    it "handles short strings gracefully" do
      similarity = instance.send(:string_similarity, "ab", "ab")
      expect(similarity).to eq(1.0)
    end

    it "handles single character strings" do
      similarity = instance.send(:string_similarity, "a", "b")
      expect(similarity).to eq(0.0)
    end
  end

  describe "#trigrams" do
    it "extracts character trigrams from a string" do
      result = instance.send(:trigrams, "hello")
      expect(result).to be_a(Set)
      expect(result).to include("hel", "ell", "llo")
      expect(result.size).to eq(3)
    end

    it "returns empty set for strings shorter than 3 characters" do
      expect(instance.send(:trigrams, "ab")).to eq(Set.new)
      expect(instance.send(:trigrams, "a")).to eq(Set.new)
      expect(instance.send(:trigrams, "")).to eq(Set.new)
    end

    it "handles exactly 3 character strings" do
      result = instance.send(:trigrams, "abc")
      expect(result).to eq(Set.new(["abc"]))
    end
  end

  # === Guidance Generation Tests ===

  describe "#generate_tool_guidance" do
    it "includes the tool name" do
      guidance = instance.send(:generate_tool_guidance, "search", 3)
      expect(guidance).to include("search")
    end

    it "includes the repetition count" do
      guidance = instance.send(:generate_tool_guidance, "search", 5)
      expect(guidance).to include("5 times")
    end

    it "suggests a different approach" do
      guidance = instance.send(:generate_tool_guidance, "search", 3)
      expect(guidance).to include("different approach")
    end
  end

  describe "#generate_code_guidance" do
    it "includes the repetition count" do
      guidance = instance.send(:generate_code_guidance, 4)
      expect(guidance).to include("4 times")
    end

    it "mentions same code" do
      guidance = instance.send(:generate_code_guidance, 3)
      expect(guidance).to include("same code")
    end

    it "suggests a different approach" do
      guidance = instance.send(:generate_code_guidance, 3)
      expect(guidance).to include("different approach")
    end
  end

  describe "#generate_observation_guidance" do
    it "includes the repetition count" do
      guidance = instance.send(:generate_observation_guidance, 3)
      expect(guidance).to include("3 times")
    end

    it "mentions same result" do
      guidance = instance.send(:generate_observation_guidance, 3)
      expect(guidance).to include("same result")
    end

    it "suggests different tool or inputs" do
      guidance = instance.send(:generate_observation_guidance, 3)
      expect(guidance).to include("different tool or inputs")
    end
  end

  # === Detection Tests ===

  describe "#detect_tool_call_repetition" do
    it "detects identical tool calls" do
      tool_call = tool_call_class.new(name: "search", arguments: { query: "ruby" })
      steps = Array.new(3) { step_class.new(tool_calls: [tool_call]) }

      result = instance.send(:detect_tool_call_repetition, steps)

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

      result = instance.send(:detect_tool_call_repetition, steps)
      expect(result).to be_nil
    end

    it "normalizes argument comparison (case-insensitive, trimmed)" do
      steps = [
        step_class.new(tool_calls: [tool_call_class.new(name: "search", arguments: { query: "Ruby" })]),
        step_class.new(tool_calls: [tool_call_class.new(name: "search", arguments: { query: "ruby " })]),
        step_class.new(tool_calls: [tool_call_class.new(name: "search", arguments: { query: " RUBY" })])
      ]

      result = instance.send(:detect_tool_call_repetition, steps)
      expect(result).not_to be_nil
      expect(result.pattern).to eq(:tool_call)
    end

    it "returns nil for steps without tool calls" do
      steps = Array.new(3) { step_class.new(code_action: "some_code()") }
      result = instance.send(:detect_tool_call_repetition, steps)
      expect(result).to be_nil
    end
  end

  describe "#detect_code_action_repetition" do
    it "detects identical code actions" do
      code = "search(query: 'test')"
      steps = Array.new(3) { step_class.new(code_action: code) }

      result = instance.send(:detect_code_action_repetition, steps)

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

      result = instance.send(:detect_code_action_repetition, steps)
      expect(result).not_to be_nil
      expect(result.pattern).to eq(:code_action)
    end

    it "returns nil for different code actions" do
      steps = [
        step_class.new(code_action: "search(query: 'ruby')"),
        step_class.new(code_action: "search(query: 'python')"),
        step_class.new(code_action: "visit(url: 'http://test.com')")
      ]

      result = instance.send(:detect_code_action_repetition, steps)
      expect(result).to be_nil
    end
  end

  describe "#detect_observation_repetition" do
    it "detects identical observations" do
      observation = "No results found for your query."
      steps = Array.new(3) { step_class.new(observations: observation) }

      result = instance.send(:detect_observation_repetition, steps, 0.9)

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

      result = instance.send(:detect_observation_repetition, steps, 0.9)
      expect(result).not_to be_nil
      expect(result.pattern).to eq(:observation)
    end

    it "returns nil for sufficiently different observations" do
      steps = [
        step_class.new(observations: "Found 5 results for Ruby programming"),
        step_class.new(observations: "Found 3 results for Python libraries"),
        step_class.new(observations: "Found 10 results for web frameworks")
      ]

      result = instance.send(:detect_observation_repetition, steps, 0.9)
      expect(result).to be_nil
    end

    it "returns nil with fewer than 2 observations" do
      steps = [step_class.new(observations: "Single observation")]
      result = instance.send(:detect_observation_repetition, steps, 0.9)
      expect(result).to be_nil
    end
  end

  describe "#normalize_arguments" do
    it "converts values to lowercase and trims whitespace" do
      args = { query: " Ruby ", name: "HELLO" }
      result = instance.send(:normalize_arguments, args)
      expect(result).to eq({ query: "ruby", name: "hello" })
    end

    it "returns empty hash for nil" do
      expect(instance.send(:normalize_arguments, nil)).to eq({})
    end
  end

  describe "#normalize_code" do
    it "collapses multiple whitespace to single space" do
      code = "search(query:   'test')"
      result = instance.send(:normalize_code, code)
      expect(result).to eq("search(query: 'test')")
    end

    it "strips leading and trailing whitespace" do
      code = "  search()  "
      result = instance.send(:normalize_code, code)
      expect(result).to eq("search()")
    end
  end
end
