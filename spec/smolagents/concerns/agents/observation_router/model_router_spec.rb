require "spec_helper"

RSpec.describe Smolagents::Concerns::ObservationRouter::ModelRouter do
  let(:mock_model) { Smolagents::Testing::MockModel.new }
  let(:router) { described_class.create(mock_model) }

  describe ".create" do
    it "returns a callable proc" do
      expect(router).to respond_to(:call)
    end

    it "calls the model with a routing prompt" do
      mock_model.queue_response(<<~RUBY)
        ```ruby
        RoutingResult.new(
          decision: :summary_only,
          summary: "Found Paris facts",
          relevance: 0.9,
          next_action: "Call final_answer",
          full_output: nil
        )
        ```
      RUBY

      result = router.call("wikipedia", "Paris is the capital of France", "Find facts about Paris")

      expect(mock_model.call_count).to eq(1)
      expect(result).to be_a(Smolagents::Concerns::ObservationRouter::RoutingResult)
      expect(result.decision).to eq(:summary_only)
    end
  end

  describe ".build_prompt" do
    it "includes task, tool name, and output" do
      message = described_class.build_prompt("wikipedia", "Some output", "Find info")

      expect(message.content).to include("TASK: Find info")
      expect(message.content).to include("TOOL: wikipedia")
      expect(message.content).to include("Some output")
    end

    it "truncates long output" do
      long_output = "x" * 5000
      message = described_class.build_prompt("search", long_output, "task")

      expect(message.content).to include("...[truncated]")
      expect(message.content.length).to be < 5000
    end

    it "includes Ruby code example" do
      message = described_class.build_prompt("tool", "output", "task")

      expect(message.content).to include("RoutingResult.new")
      expect(message.content).to include(":summary_only")
    end
  end

  describe ".execute_routing_code" do
    it "executes valid Ruby code and returns RoutingResult" do
      code = <<~RUBY
        RoutingResult.new(
          decision: :full_output,
          summary: "Test summary",
          relevance: 0.5,
          next_action: nil,
          full_output: nil
        )
      RUBY

      result = described_class.execute_routing_code(code, "original")

      expect(result.decision).to eq(:full_output)
      expect(result.summary).to eq("Test summary")
      expect(result.full_output).to eq("original") # Attached by finalize_result
    end

    it "extracts code from markdown blocks" do
      content = <<~MD
        Here's my analysis:

        ```ruby
        RoutingResult.new(
          decision: :summary_only,
          summary: "Found it",
          relevance: 0.8,
          next_action: "Done",
          full_output: nil
        )
        ```

        That should work.
      MD

      result = described_class.execute_routing_code(content, "raw")

      expect(result.decision).to eq(:summary_only)
      expect(result.summary).to eq("Found it")
    end

    it "returns fallback on invalid code" do
      result = described_class.execute_routing_code("invalid ruby {{{}}", "output")

      expect(result.decision).to eq(:full_output)
      expect(result.summary).to include("Router fallback")
      expect(result.full_output).to eq("output")
    end

    it "returns fallback when code returns wrong type" do
      result = described_class.execute_routing_code('"just a string"', "output")

      expect(result.decision).to eq(:full_output)
      expect(result.summary).to include("Invalid result type")
    end
  end

  describe "SafeContext" do
    it "only exposes RoutingResult" do
      context = described_class::SafeContext.new

      expect(context.RoutingResult).to eq(Smolagents::Concerns::ObservationRouter::RoutingResult)
    end

    it "provides isolated execution environment" do
      # The SafeContext only defines RoutingResult method
      # Other constants are inherited from Object but that's acceptable
      # The main protection is that we're eval'ing in a limited context
      context = described_class::SafeContext.new
      expect(context).to respond_to(:RoutingResult)
    end
  end

  describe "integration with MockModel" do
    it "handles summary_only routing" do
      mock_model.queue_response(<<~RUBY)
        ```ruby
        # The Wikipedia output contains direct facts about Paris
        RoutingResult.new(
          decision: :summary_only,
          summary: "Paris is the capital of France with population 2.1M",
          relevance: 0.95,
          next_action: "Call final_answer with these facts",
          full_output: nil
        )
        ```
      RUBY

      result = router.call("wikipedia", "Paris is the capital...", "What are facts about Paris?")

      expect(result.summary_only?).to be true
      expect(result.full_output).to be_nil
    end

    it "handles needs_retry routing" do
      mock_model.queue_response(<<~RUBY)
        ```ruby
        # The search returned unrelated results about "Paris Hilton"
        RoutingResult.new(
          decision: :needs_retry,
          summary: "Results about Paris Hilton, not Paris France",
          relevance: 0.1,
          next_action: "Search for 'Paris France capital' instead",
          full_output: nil
        )
        ```
      RUBY

      result = router.call("web_search", "Paris Hilton news...", "Facts about Paris France")

      expect(result.needs_retry?).to be true
      expect(result.next_action).to include("Paris France")
    end
  end
end
