require "spec_helper"

RSpec.describe Smolagents::Concerns::GoalAwareYield do
  let(:goal) do
    Smolagents::Types::Goal.create(description: "Find Ruby release notes")
  end

  let(:tool_call) do
    Smolagents::ToolCall.new(id: "tc_1", name: "search", arguments: { query: "ruby" })
  end

  # Test class with full concern chain
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::GoalTracking
      include Smolagents::Concerns::EarlyYield
      include Smolagents::Concerns::GoalAwareYield

      attr_accessor :tool_results

      def initialize
        initialize_goal_tracking
        @tool_results = {}
      end

      def execute_tool_call(call)
        @tool_results[call.id] || "default result"
      end
    end
  end

  let(:instance) { test_class.new }

  describe "#execute_tools_for_goal" do
    context "with active goal" do
      before do
        instance.goal_store.add(goal)
        instance.tool_results["tc_1"] = "Found Ruby 3.3 release notes with detailed changelog"
      end

      it "executes tool calls" do
        result = instance.execute_tools_for_goal([tool_call])

        expect(result.results.size).to eq(1)
        expect(result.results.first).to include("Ruby 3.3")
      end

      it "returns EarlyYieldResult" do
        result = instance.execute_tools_for_goal([tool_call])

        expect(result).to be_a(Smolagents::Concerns::EarlyYield::EarlyYieldResult)
      end
    end

    context "without goal" do
      before do
        instance.tool_results["tc_1"] = "result"
      end

      it "falls back to standard execution" do
        result = instance.execute_tools_for_goal([tool_call])

        expect(result.results.size).to eq(1)
        expect(result.complete?).to be true
      end
    end

    context "with custom predicate" do
      let(:second_tool_call) do
        Smolagents::ToolCall.new(id: "tc_2", name: "search", arguments: { query: "docs" })
      end

      before do
        instance.goal_store.add(goal)
        instance.tool_results["tc_1"] = "Not quite right"
        instance.tool_results["tc_2"] = "Found exactly what we need"
      end

      it "uses custom predicate" do
        called_with_goal = nil

        # Need multiple tool calls for predicate to be used
        result = instance.execute_tools_for_goal([tool_call, second_tool_call]) do |res, current_goal|
          called_with_goal = current_goal
          res.include?("exactly")
        end

        expect(called_with_goal).to eq(goal)
        expect(result.early_result).to include("exactly")
      end
    end
  end

  describe "#result_advances_goal?" do
    before do
      instance.goal_store.add(goal)
    end

    it "returns true for substantive non-error output" do
      result = instance.send(:result_advances_goal?, "Found 5 relevant documents about Ruby", goal)

      expect(result).to be true
    end

    it "returns false for short output" do
      result = instance.send(:result_advances_goal?, "OK", goal)

      expect(result).to be false
    end

    it "returns false for error-like output" do
      result = instance.send(:result_advances_goal?, "Error: Connection failed to server", goal)

      expect(result).to be false
    end

    it "returns false for nil output" do
      result = instance.send(:result_advances_goal?, nil, goal)

      expect(result).to be false
    end

    it "returns false for completed goal" do
      completed = goal.complete(evidence: "done")
      result = instance.send(:result_advances_goal?, "good output here", completed)

      expect(result).to be false
    end
  end

  describe "#extract_output" do
    it "extracts from string" do
      output = instance.send(:extract_output, "direct string")

      expect(output).to eq("direct string")
    end

    it "extracts from hash with symbol key" do
      output = instance.send(:extract_output, { output: "hash output" })

      expect(output).to eq("hash output")
    end

    it "extracts from hash with string key" do
      output = instance.send(:extract_output, { "output" => "string key" })

      expect(output).to eq("string key")
    end

    it "extracts from object with output method" do
      obj = Data.define(:output).new(output: "object output")
      output = instance.send(:extract_output, obj)

      expect(output).to eq("object output")
    end

    it "falls back to to_s" do
      output = instance.send(:extract_output, 42)

      expect(output).to eq("42")
    end
  end

  describe "#looks_like_error?" do
    it "detects error messages" do
      expect(instance.send(:looks_like_error?, "Error occurred")).to be true
      expect(instance.send(:looks_like_error?, "Connection failed")).to be true
      expect(instance.send(:looks_like_error?, "File not found")).to be true
      expect(instance.send(:looks_like_error?, "Invalid input")).to be true
    end

    it "allows normal messages" do
      expect(instance.send(:looks_like_error?, "Found 5 results")).to be false
      expect(instance.send(:looks_like_error?, "Processing complete")).to be false
    end
  end

  describe "without EarlyYield" do
    let(:minimal_class) do
      Class.new do
        include Smolagents::Concerns::GoalTracking
        include Smolagents::Concerns::GoalAwareYield

        def initialize
          initialize_goal_tracking
        end

        def execute_tool_call(call)
          "result for #{call.id}"
        end
      end
    end

    it "falls back to standard execution" do
      minimal = minimal_class.new
      minimal.goal_store.add(goal)

      result = minimal.execute_tools_for_goal([tool_call])

      expect(result.results.size).to eq(1)
      expect(result.complete?).to be true
    end
  end
end
