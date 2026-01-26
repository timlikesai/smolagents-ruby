require "smolagents/concerns/agents/step_context"

RSpec.describe Smolagents::Concerns::StepContext do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::StepContext

      attr_accessor :max_steps, :ctx, :executor

      def initialize
        @max_steps = 10
        @ctx = nil
        @executor = nil
      end
    end
  end

  let(:instance) { test_class.new }

  # Use simple doubles instead of instance_doubles since the classes may not exist
  let(:mock_context) do
    double("Context", step_number: 2)
  end

  let(:mock_tool_call) do
    double("ToolCall",
           tool_name: "web_search",
           success?: true,
           duration: 1.23)
  end

  let(:mock_executor) do
    double("Executor", tool_calls: [mock_tool_call])
  end

  describe "#build_step_context" do
    context "when neither max_steps nor executor is set" do
      it "returns nil" do
        instance.max_steps = nil
        instance.ctx = nil
        instance.executor = nil

        result = instance.send(:build_step_context)
        expect(result).to be_nil
      end
    end

    context "when max_steps is set" do
      before do
        instance.max_steps = 10
        instance.ctx = mock_context
      end

      it "includes step budget context" do
        result = instance.send(:build_step_context)
        expect(result).to include("[CONTEXT]")
        expect(result).to include("Step: 3 of 10")
      end
    end

    context "when executor with tool calls is set" do
      before do
        instance.executor = mock_executor
      end

      it "includes last tool context" do
        result = instance.send(:build_step_context)
        expect(result).to include("Last: web_search")
        expect(result).to include("✓")
        expect(result).to include("1.2s")
      end
    end

    context "with both step budget and last tool context" do
      before do
        instance.max_steps = 10
        instance.ctx = mock_context
        instance.executor = mock_executor
      end

      it "includes both contexts" do
        result = instance.send(:build_step_context)
        expect(result).to include("Step: 3 of 10 (7 remaining)")
        expect(result).to include("Last: web_search ✓ 1.2s")
      end

      it "formats with [CONTEXT] header" do
        result = instance.send(:build_step_context)
        lines = result.split("\n")
        expect(lines[0]).to eq("[CONTEXT]")
      end
    end
  end

  describe "#step_budget_context" do
    context "when max_steps is not set" do
      before do
        instance.max_steps = nil
      end

      it "returns nil" do
        result = instance.send(:step_budget_context)
        expect(result).to be_nil
      end
    end

    context "when ctx is not set" do
      before do
        instance.max_steps = 10
        instance.ctx = nil
      end

      it "returns nil" do
        result = instance.send(:step_budget_context)
        expect(result).to be_nil
      end
    end

    context "when both are set" do
      before do
        instance.max_steps = 10
        instance.ctx = mock_context # step_number: 2
      end

      it "returns formatted budget string" do
        result = instance.send(:step_budget_context)
        expect(result).to eq("Step: 3 of 10 (7 remaining)")
      end

      it "uses 1-indexed current step" do
        instance.ctx = double("Context", step_number: 0)
        result = instance.send(:step_budget_context)
        expect(result).to eq("Step: 1 of 10 (9 remaining)")
      end

      it "calculates remaining correctly" do
        instance.max_steps = 5
        instance.ctx = double("Context", step_number: 2)
        result = instance.send(:step_budget_context)
        expect(result).to eq("Step: 3 of 5 (2 remaining)")
      end

      it "handles final step" do
        instance.max_steps = 10
        instance.ctx = double("Context", step_number: 9)
        result = instance.send(:step_budget_context)
        expect(result).to eq("Step: 10 of 10 (0 remaining)")
      end
    end
  end

  describe "#last_tool_context" do
    context "when executor does not respond to tool_calls" do
      before do
        instance.executor = nil
      end

      it "returns nil" do
        result = instance.send(:last_tool_context)
        expect(result).to be_nil
      end
    end

    context "when executor has no tool calls" do
      before do
        instance.executor = double("Executor", tool_calls: [])
      end

      it "returns nil" do
        result = instance.send(:last_tool_context)
        expect(result).to be_nil
      end
    end

    context "when last tool call succeeded" do
      before do
        instance.executor = mock_executor
      end

      it "returns formatted success context" do
        result = instance.send(:last_tool_context)
        expect(result).to include("web_search")
        expect(result).to include("✓")
        expect(result).to include("1.2s")
      end

      it "formats duration with one decimal place" do
        tool_call = double("ToolCall",
                           tool_name: "search",
                           success?: true,
                           duration: 1.2345)
        executor = double("Executor", tool_calls: [tool_call])
        instance.executor = executor

        result = instance.send(:last_tool_context)
        expect(result).to include("1.2s")
      end
    end

    context "when last tool call failed" do
      before do
        tool_call = double("ToolCall",
                           tool_name: "web_search",
                           success?: false,
                           duration: 0.5)
        instance.executor = double("Executor", tool_calls: [tool_call])
      end

      it "returns formatted failure context with X status" do
        result = instance.send(:last_tool_context)
        expect(result).to include("web_search")
        expect(result).to include("✗")
        expect(result).to include("0.5s")
      end
    end

    context "with multiple tool calls" do
      before do
        call1 = double("ToolCall",
                       tool_name: "search",
                       success?: true,
                       duration: 1.0)
        call2 = double("ToolCall",
                       tool_name: "parse",
                       success?: true,
                       duration: 0.8)

        instance.executor = double("Executor", tool_calls: [call1, call2])
      end

      it "returns information about the last tool call only" do
        result = instance.send(:last_tool_context)
        expect(result).to include("parse")
        expect(result).not_to include("search")
      end
    end
  end

  describe "integration" do
    let(:tool_call1) do
      double("ToolCall",
             tool_name: "web_search",
             success?: true,
             duration: 2.1)
    end

    let(:tool_call2) do
      double("ToolCall",
             tool_name: "parse_html",
             success?: true,
             duration: 1.3)
    end

    it "builds complete step context with budget and last tool" do
      instance.max_steps = 15
      instance.ctx = double("Context", step_number: 4)
      instance.executor = double("Executor", tool_calls: [tool_call1, tool_call2])

      result = instance.send(:build_step_context)

      expect(result).to include("[CONTEXT]")
      expect(result).to include("Step: 5 of 15 (10 remaining)")
      expect(result).to include("Last: parse_html ✓ 1.3s")
    end

    it "handles partial context gracefully" do
      instance.max_steps = 10
      instance.ctx = double("Context", step_number: 5)
      instance.executor = nil

      result = instance.send(:build_step_context)

      expect(result).to include("[CONTEXT]")
      expect(result).to include("Step: 6 of 10 (4 remaining)")
    end

    it "returns nil when no context data is available" do
      instance.max_steps = nil
      instance.ctx = nil
      instance.executor = nil

      result = instance.send(:build_step_context)
      expect(result).to be_nil
    end
  end
end
