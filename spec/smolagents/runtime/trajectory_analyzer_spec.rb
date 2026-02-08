require "spec_helper"

RSpec.describe Smolagents::Runtime::TrajectoryAnalyzer do
  let(:search_tool_call) { Smolagents::Types::ToolCall.new(name: "search", arguments: { query: "Ruby" }, id: "tc1") }
  let(:calc_tool_call) { Smolagents::Types::ToolCall.new(name: "calculator", arguments: { expr: "2+2" }, id: "tc2") }

  def build_action_step(step_number:, tool_calls: nil, observations: nil, error: nil)
    Smolagents::Types::ActionStep.new(
      step_number: step_number,
      tool_calls: tool_calls,
      observations: observations,
      error: error
    )
  end

  def build_planning_step(plan:)
    Smolagents::Types::PlanningStep.new(
      model_input_messages: [],
      model_output_message: nil,
      plan: plan,
      timing: nil,
      token_usage: nil
    )
  end

  describe "#segment" do
    it "returns empty array for empty steps" do
      analyzer = described_class.new([])

      expect(analyzer.segment).to eq([])
    end

    it "segments consecutive steps by label" do
      steps = [
        build_action_step(step_number: 1, tool_calls: [search_tool_call], observations: "Found results"),
        build_action_step(step_number: 2, tool_calls: [search_tool_call], observations: "More results"),
        build_action_step(step_number: 3, tool_calls: [calc_tool_call], observations: "4")
      ]
      analyzer = described_class.new(steps)

      segments = analyzer.segment

      expect(segments.size).to eq(2)
      expect(segments[0].label).to eq(:search)
      expect(segments[0].step_count).to eq(2)
      expect(segments[1].label).to eq(:tool_execution)
      expect(segments[1].step_count).to eq(1)
    end

    it "creates single segment for uniform steps" do
      steps = [
        build_action_step(step_number: 1, tool_calls: [calc_tool_call], observations: "1"),
        build_action_step(step_number: 2, tool_calls: [calc_tool_call], observations: "2"),
        build_action_step(step_number: 3, tool_calls: [calc_tool_call], observations: "3")
      ]
      analyzer = described_class.new(steps)

      segments = analyzer.segment

      expect(segments.size).to eq(1)
      expect(segments[0].label).to eq(:tool_execution)
      expect(segments[0].step_count).to eq(3)
    end

    it "classifies search steps correctly" do
      steps = [
        build_action_step(step_number: 1, tool_calls: [search_tool_call], observations: "Results")
      ]
      analyzer = described_class.new(steps)

      segments = analyzer.segment

      expect(segments[0].label).to eq(:search)
    end

    it "classifies error recovery steps" do
      steps = [
        build_action_step(step_number: 1, error: "Connection failed"),
        build_action_step(step_number: 2, error: "Retry failed")
      ]
      analyzer = described_class.new(steps)

      segments = analyzer.segment

      expect(segments[0].label).to eq(:error_recovery)
      expect(segments[0].step_count).to eq(2)
    end

    it "classifies planning steps" do
      steps = [
        build_planning_step(plan: "Step 1: Search\nStep 2: Process")
      ]
      analyzer = described_class.new(steps)

      segments = analyzer.segment

      expect(segments[0].label).to eq(:planning)
      expect(segments[0].start_step).to be_nil # PlanningStep has no step_number
      expect(segments[0].end_step).to be_nil
    end

    it "classifies tool execution steps" do
      steps = [
        build_action_step(step_number: 1, tool_calls: [calc_tool_call], observations: "4")
      ]
      analyzer = described_class.new(steps)

      segments = analyzer.segment

      expect(segments[0].label).to eq(:tool_execution)
    end

    it "classifies steps without tool calls as default" do
      steps = [
        build_action_step(step_number: 1, observations: "Just thinking")
      ]
      analyzer = described_class.new(steps)

      segments = analyzer.segment

      expect(segments[0].label).to eq(:default)
    end

    it "handles mixed step types" do
      steps = [
        build_action_step(step_number: 1, tool_calls: [search_tool_call], observations: "Found"),
        build_action_step(step_number: 2, error: "Failed"),
        build_action_step(step_number: 3, tool_calls: [calc_tool_call], observations: "4")
      ]
      analyzer = described_class.new(steps)

      segments = analyzer.segment

      expect(segments.map(&:label)).to eq([:search, :error_recovery, :tool_execution])
    end

    it "sets correct step ranges for segments" do
      steps = [
        build_action_step(step_number: 1, tool_calls: [search_tool_call], observations: "1"),
        build_action_step(step_number: 2, tool_calls: [search_tool_call], observations: "2"),
        build_action_step(step_number: 3, tool_calls: [calc_tool_call], observations: "3")
      ]
      analyzer = described_class.new(steps)

      segments = analyzer.segment

      expect(segments[0].step_range).to eq(1..2)
      expect(segments[1].step_range).to eq(3..3)
    end

    it "returns TrajectorySegment instances" do
      steps = [build_action_step(step_number: 1, observations: "Test")]
      analyzer = described_class.new(steps)

      segments = analyzer.segment

      expect(segments[0]).to be_a(Smolagents::Types::TrajectorySegment)
    end
  end

  describe "#extract_decision_points" do
    it "returns empty array for empty steps" do
      analyzer = described_class.new([])

      expect(analyzer.extract_decision_points).to eq([])
    end

    it "extracts tool calls from steps" do
      steps = [
        build_action_step(step_number: 1, tool_calls: [search_tool_call], observations: "Results"),
        build_action_step(step_number: 2, tool_calls: [calc_tool_call], observations: "4")
      ]
      analyzer = described_class.new(steps)

      points = analyzer.extract_decision_points

      expect(points).to eq([
        "Step 1: search",
        "Step 2: calculator"
      ])
    end

    it "joins multiple tool calls per step" do
      multi_call = [search_tool_call, calc_tool_call]
      steps = [
        build_action_step(step_number: 1, tool_calls: multi_call, observations: "Results")
      ]
      analyzer = described_class.new(steps)

      points = analyzer.extract_decision_points

      expect(points).to eq(["Step 1: search, calculator"])
    end

    it "skips steps without tool calls" do
      steps = [
        build_action_step(step_number: 1, observations: "Thinking"),
        build_action_step(step_number: 2, tool_calls: [search_tool_call], observations: "Found")
      ]
      analyzer = described_class.new(steps)

      points = analyzer.extract_decision_points

      expect(points).to eq(["Step 2: search"])
    end

    it "skips planning steps" do
      steps = [
        build_planning_step(plan: "Plan"),
        build_action_step(step_number: 1, tool_calls: [search_tool_call], observations: "Found")
      ]
      analyzer = described_class.new(steps)

      points = analyzer.extract_decision_points

      expect(points).to eq(["Step 1: search"])
    end
  end

  describe "#classify_outcome" do
    it "returns :unknown for empty steps" do
      analyzer = described_class.new([])

      expect(analyzer.classify_outcome([])).to eq(:unknown)
    end

    it "returns :success when all steps have observations" do
      steps = [
        build_action_step(step_number: 1, observations: "Result 1"),
        build_action_step(step_number: 2, observations: "Result 2")
      ]
      analyzer = described_class.new(steps)

      expect(analyzer.classify_outcome(steps)).to eq(:success)
    end

    it "returns :failure when all steps have errors and no observations" do
      steps = [
        build_action_step(step_number: 1, error: "Error 1"),
        build_action_step(step_number: 2, error: "Error 2")
      ]
      analyzer = described_class.new(steps)

      expect(analyzer.classify_outcome(steps)).to eq(:failure)
    end

    it "returns :partial when some steps have errors and some have observations" do
      steps = [
        build_action_step(step_number: 1, observations: "Success"),
        build_action_step(step_number: 2, error: "Failed")
      ]
      analyzer = described_class.new(steps)

      expect(analyzer.classify_outcome(steps)).to eq(:partial)
    end

    it "returns :unknown when no errors and no observations" do
      steps = [
        build_action_step(step_number: 1)
      ]
      analyzer = described_class.new(steps)

      expect(analyzer.classify_outcome(steps)).to eq(:unknown)
    end

    it "treats empty string observations as no observations" do
      steps = [
        build_action_step(step_number: 1, observations: "")
      ]
      analyzer = described_class.new(steps)

      expect(analyzer.classify_outcome(steps)).to eq(:unknown)
    end
  end

  describe "LABELS constant" do
    it "contains expected label keys" do
      expect(described_class::LABELS.keys).to include(:search, :error_recovery, :planning, :tool_execution, :default)
    end

    it "has callable predicates" do
      described_class::LABELS.each_value do |predicate|
        expect(predicate).to respond_to(:call)
      end
    end
  end

  describe "class methods for step classification" do
    describe ".search_step?" do
      it "returns true for search tool calls" do
        step = build_action_step(step_number: 1, tool_calls: [search_tool_call])

        expect(described_class.search_step?(step)).to be true
      end

      it "returns false for non-search tool calls" do
        step = build_action_step(step_number: 1, tool_calls: [calc_tool_call])

        expect(described_class.search_step?(step)).to be false
      end

      it "returns false when no tool calls" do
        step = build_action_step(step_number: 1)

        expect(described_class.search_step?(step)).to be false
      end

      it "matches case-insensitively" do
        upper_search = Smolagents::Types::ToolCall.new(name: "SEARCH_WEB", arguments: {}, id: "tc")
        step = build_action_step(step_number: 1, tool_calls: [upper_search])

        expect(described_class.search_step?(step)).to be true
      end
    end

    describe ".error_step?" do
      it "returns true when step has error" do
        step = build_action_step(step_number: 1, error: "Something failed")

        expect(described_class.error_step?(step)).to be true
      end

      it "returns false when no error" do
        step = build_action_step(step_number: 1, observations: "Success")

        expect(described_class.error_step?(step)).to be false
      end
    end

    describe ".planning_step?" do
      it "returns true for PlanningStep" do
        step = build_planning_step(plan: "Plan")

        expect(described_class.planning_step?(step)).to be true
      end

      it "returns false for ActionStep" do
        step = build_action_step(step_number: 1)

        expect(described_class.planning_step?(step)).to be false
      end
    end

    describe ".tool_execution_step?" do
      it "returns true when step has tool calls" do
        step = build_action_step(step_number: 1, tool_calls: [calc_tool_call])

        expect(described_class.tool_execution_step?(step)).to be true
      end

      it "returns false when no tool calls" do
        step = build_action_step(step_number: 1)

        expect(described_class.tool_execution_step?(step)).to be false
      end

      it "returns false for empty tool calls array" do
        step = build_action_step(step_number: 1, tool_calls: [])

        expect(described_class.tool_execution_step?(step)).to be false
      end
    end
  end

  describe "segment outcome classification" do
    it "sets segment outcomes based on step content" do
      steps = [
        build_action_step(step_number: 1, tool_calls: [search_tool_call], observations: "Found"),
        build_action_step(step_number: 2, tool_calls: [search_tool_call], observations: "More")
      ]
      analyzer = described_class.new(steps)

      segments = analyzer.segment

      expect(segments[0].outcome).to eq(:success)
    end

    it "sets failure outcome for error-only segments" do
      steps = [
        build_action_step(step_number: 1, error: "Failed")
      ]
      analyzer = described_class.new(steps)

      segments = analyzer.segment

      expect(segments[0].outcome).to eq(:failure)
    end
  end
end
