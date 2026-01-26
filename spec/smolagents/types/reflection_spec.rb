RSpec.describe Smolagents::Types::ReflectionConfig do
  describe ".default" do
    it "creates config with default values" do
      config = described_class.default

      expect(config.max_reflections).to eq(10)
      expect(config.enabled).to be true
      expect(config.include_successful).to be false
    end

    it "is frozen" do
      config = described_class.default

      expect(config).to be_frozen
    end
  end

  describe ".disabled" do
    it "creates config with reflection disabled" do
      config = described_class.disabled

      expect(config.max_reflections).to eq(0)
      expect(config.enabled).to be false
      expect(config.include_successful).to be false
    end

    it "is frozen" do
      config = described_class.disabled

      expect(config).to be_frozen
    end
  end

  describe "default values" do
    it "max_reflections defaults to 10" do
      expect(described_class.default.max_reflections).to eq(10)
    end
  end

  describe "attributes" do
    it "allows custom configuration" do
      config = described_class.new(
        max_reflections: 20,
        enabled: true,
        include_successful: true
      )

      expect(config.max_reflections).to eq(20)
      expect(config.enabled).to be true
      expect(config.include_successful).to be true
    end
  end
end

RSpec.describe Smolagents::Types::Reflection do
  let(:timestamp) { Time.now }

  describe "attributes" do
    it "has all required fields" do
      reflection = described_class.new(
        task: "Search for Ruby docs",
        action: "web_search(query)",
        outcome: :success,
        observation: "Found 10 results",
        reflection: "Use more specific queries",
        timestamp:
      )

      expect(reflection.task).to eq("Search for Ruby docs")
      expect(reflection.action).to eq("web_search(query)")
      expect(reflection.outcome).to eq(:success)
      expect(reflection.observation).to eq("Found 10 results")
      expect(reflection.reflection).to eq("Use more specific queries")
      expect(reflection.timestamp).to eq(timestamp)
    end
  end

  describe "#failure?" do
    it "returns true when outcome is :failure" do
      reflection = described_class.new(
        task: "x",
        action: "y",
        outcome: :failure,
        observation: "error",
        reflection: "try again",
        timestamp:
      )

      expect(reflection.failure?).to be true
    end

    it "returns false for other outcomes" do
      %i[success partial].each do |outcome|
        reflection = described_class.new(
          task: "x",
          action: "y",
          outcome:,
          observation: "z",
          reflection: "w",
          timestamp:
        )

        expect(reflection.failure?).to be false
      end
    end
  end

  describe "#success?" do
    it "returns true when outcome is :success" do
      reflection = described_class.new(
        task: "x",
        action: "y",
        outcome: :success,
        observation: "done",
        reflection: "good approach",
        timestamp:
      )

      expect(reflection.success?).to be true
    end

    it "returns false for other outcomes" do
      %i[failure partial].each do |outcome|
        reflection = described_class.new(
          task: "x",
          action: "y",
          outcome:,
          observation: "z",
          reflection: "w",
          timestamp:
        )

        expect(reflection.success?).to be false
      end
    end
  end

  describe "#to_context" do
    it "formats reflection as context string" do
      reflection = described_class.new(
        task: "Find docs",
        action: "web_search(query: 'ruby')",
        outcome: :failure,
        observation: "Rate limited",
        reflection: "Wait before retrying",
        timestamp:
      )

      context = reflection.to_context

      expect(context).to include("Previous attempt: web_search(query: 'ruby')")
      expect(context).to include("Result: failure - Rate limited")
      expect(context).to include("Lesson: Wait before retrying")
    end
  end

  describe ".from_failure" do
    let(:step) do
      # Create a mock step with tool_calls
      tool_call = Smolagents::ToolCall.new(name: "web_search", arguments: { query: "ruby" }, id: "1")
      double(
        "ActionStep",
        tool_calls: [tool_call],
        code_action: nil,
        error: "API error",
        observations: "Something went wrong"
      )
    end

    it "creates reflection from failed step" do
      reflection = described_class.from_failure(
        task: "Find Ruby release notes",
        step:,
        reflection_text: "Try a different search term"
      )

      expect(reflection.task).to start_with("Find Ruby release notes")
      expect(reflection.action).to include("web_search")
      expect(reflection.outcome).to eq(:failure)
      expect(reflection.observation).to eq("API error")
      expect(reflection.reflection).to eq("Try a different search term")
      expect(reflection.timestamp).to be_a(Time)
    end

    it "truncates long tasks" do
      long_task = "x" * 250
      reflection = described_class.from_failure(
        task: long_task,
        step:,
        reflection_text: "lesson"
      )

      expect(reflection.task.length).to be <= 200
    end

    it "uses observations when error is nil" do
      step_without_error = double(
        "ActionStep",
        tool_calls: [Smolagents::ToolCall.new(name: "test", arguments: {}, id: "1")],
        code_action: nil,
        error: nil,
        observations: "Some observations here"
      )

      reflection = described_class.from_failure(
        task: "Test task",
        step: step_without_error,
        reflection_text: "Lesson"
      )

      expect(reflection.observation).to start_with("Some observations")
    end
  end

  describe ".from_success" do
    let(:step) do
      tool_call = Smolagents::ToolCall.new(name: "calculate", arguments: { x: 5 }, id: "1")
      double(
        "ActionStep",
        tool_calls: [tool_call],
        code_action: nil,
        action_output: "Result: 25"
      )
    end

    it "creates reflection from successful step" do
      reflection = described_class.from_success(
        task: "Calculate square",
        step:,
        reflection_text: "Direct calculations work well"
      )

      expect(reflection.task).to eq("Calculate square")
      expect(reflection.action).to include("calculate")
      expect(reflection.outcome).to eq(:success)
      expect(reflection.observation).to start_with("Result:")
      expect(reflection.reflection).to eq("Direct calculations work well")
      expect(reflection.timestamp).to be_a(Time)
    end

    it "truncates long action_output" do
      step_with_long_output = double(
        "ActionStep",
        tool_calls: [Smolagents::ToolCall.new(name: "test", arguments: {}, id: "1")],
        code_action: nil,
        action_output: "x" * 250
      )

      reflection = described_class.from_success(
        task: "Test",
        step: step_with_long_output,
        reflection_text: "Lesson"
      )

      expect(reflection.observation.length).to be <= 200
    end
  end

  describe "extract_action (private)" do
    it "extracts action from tool_calls" do
      tool_calls = [
        Smolagents::ToolCall.new(name: "search", arguments: { query: "test" }, id: "1"),
        Smolagents::ToolCall.new(name: "fetch", arguments: { url: "http://example.com" }, id: "2")
      ]
      step = double(
        "ActionStep",
        tool_calls:,
        code_action: nil,
        error: "Failed",
        observations: "Some observations"
      )

      reflection = described_class.from_failure(
        task: "Multi-tool task",
        step:,
        reflection_text: "lesson"
      )

      expect(reflection.action).to include("search(query)")
      expect(reflection.action).to include("fetch(url)")
    end

    it "extracts action from code_action when no tool_calls" do
      step = double(
        "ActionStep",
        tool_calls: [],
        code_action: "result = 1 + 1\nfinal_answer(result)",
        error: "Error",
        observations: nil
      )

      reflection = described_class.from_failure(
        task: "Code task",
        step:,
        reflection_text: "lesson"
      )

      expect(reflection.action).to include("result = 1")
    end

    it "returns 'unknown action' when no tool_calls or code_action" do
      step = double(
        "ActionStep",
        tool_calls: nil,
        code_action: nil,
        error: "Error",
        observations: nil
      )

      reflection = described_class.from_failure(
        task: "Unknown task",
        step:,
        reflection_text: "lesson"
      )

      expect(reflection.action).to eq("unknown action")
    end
  end

  describe "immutability" do
    it "is frozen" do
      reflection = described_class.new(
        task: "x",
        action: "y",
        outcome: :success,
        observation: "z",
        reflection: "w",
        timestamp:
      )

      expect(reflection).to be_frozen
    end
  end
end
