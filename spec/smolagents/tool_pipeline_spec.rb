# frozen_string_literal: true

RSpec.describe Smolagents::ToolPipeline do
  # Mock tools for testing
  let(:search_tool) do
    tool = instance_double("SearchTool")
    allow(tool).to receive(:name).and_return("search")
    allow(tool).to receive(:call).with(query: "Ruby").and_return([
      { title: "Ruby Lang", link: "https://ruby-lang.org" },
      { title: "Ruby Gems", link: "https://rubygems.org" }
    ])
    allow(tool).to receive(:call).with(query: "Python").and_return([
      { title: "Python.org", link: "https://python.org" }
    ])
    tool
  end

  let(:visit_tool) do
    tool = instance_double("VisitTool")
    allow(tool).to receive(:name).and_return("visit")
    allow(tool).to receive(:call) do |url:|
      "<html><title>Page: #{url}</title></html>"
    end
    tool
  end

  let(:extract_tool) do
    tool = instance_double("ExtractTool")
    allow(tool).to receive(:name).and_return("extract")
    allow(tool).to receive(:call) do |text:, pattern:|
      text.scan(Regexp.new(pattern)).flatten
    end
    tool
  end

  let(:tools) { { "search" => search_tool, "visit" => visit_tool, "extract" => extract_tool } }

  describe "#initialize" do
    it "accepts tools as a hash" do
      pipeline = described_class.new(tools)
      expect(pipeline.tools).to have_key("search")
    end

    it "accepts tools as an array" do
      pipeline = described_class.new([search_tool, visit_tool])
      expect(pipeline.tools).to have_key("search")
      expect(pipeline.tools).to have_key("visit")
    end

    it "normalizes symbol keys to strings" do
      pipeline = described_class.new({ search: search_tool })
      expect(pipeline.tools).to have_key("search")
    end

    it "accepts an optional name" do
      pipeline = described_class.new(tools, name: "My Pipeline")
      expect(pipeline.name).to eq("My Pipeline")
    end

    it "starts with no steps" do
      pipeline = described_class.new(tools)
      expect(pipeline.steps).to be_empty
    end
  end

  describe ".build" do
    it "creates a pipeline with DSL block" do
      pipeline = described_class.build(tools) do
        step :search, query: "Ruby"
      end

      expect(pipeline.steps.size).to eq(1)
      expect(pipeline.steps.first.tool_name).to eq("search")
    end

    it "accepts a name" do
      pipeline = described_class.build(tools, name: "Test Pipeline") do
        step :search, query: "Ruby"
      end

      expect(pipeline.name).to eq("Test Pipeline")
    end
  end

  describe ".execute" do
    it "executes a one-off pipeline" do
      result = described_class.execute(tools,
        { tool: :search, args: { query: "Ruby" } }
      )

      expect(result).to be_a(Smolagents::ToolResult)
      expect(result.count).to eq(2)
    end

    it "chains multiple steps" do
      result = described_class.execute(tools,
        { tool: :search, args: { query: "Ruby" } },
        { tool: :visit, args_from: ->(prev) { { url: prev.first[:link] } } }
      )

      expect(result.to_s).to include("ruby-lang.org")
    end
  end

  describe "#step" do
    let(:pipeline) { described_class.new(tools) }

    it "adds a step with static args" do
      pipeline.step(:search, query: "Ruby")

      expect(pipeline.steps.size).to eq(1)
      expect(pipeline.steps.first.static_args).to eq({ query: "Ruby" })
    end

    it "adds a step with dynamic args" do
      pipeline.step(:visit) { |prev| { url: prev.first[:link] } }

      expect(pipeline.steps.first.dynamic_args).to be_a(Proc)
    end

    it "accepts a custom name" do
      pipeline.step(:search, name: "find_ruby", query: "Ruby")

      expect(pipeline.steps.first.name).to eq("find_ruby")
      expect(pipeline.steps.first.label).to eq("find_ruby")
    end

    it "returns self for chaining" do
      result = pipeline.step(:search, query: "Ruby")
      expect(result).to eq(pipeline)
    end

    it "is aliased as then_do" do
      pipeline.then_do(:search, query: "Ruby")
      expect(pipeline.steps.size).to eq(1)
    end
  end

  describe "#transform" do
    let(:pipeline) { described_class.new(tools) }

    it "adds a transform step" do
      pipeline.step(:search, query: "Ruby")
      pipeline.transform("get_titles") { |result| result.pluck(:title) }

      expect(pipeline.steps.size).to eq(2)
      expect(pipeline.steps.last.tool_name).to eq("__transform__")
    end

    it "executes transform on results" do
      pipeline.step(:search, query: "Ruby")
      pipeline.transform { |result| result.map { |r| r[:title].upcase } }

      result = pipeline.run
      expect(result.to_a).to eq(["RUBY LANG", "RUBY GEMS"])
    end
  end

  describe "#add_step" do
    let(:pipeline) { described_class.new(tools) }

    it "adds a step programmatically" do
      pipeline.add_step(:search, query: "Ruby")
      expect(pipeline.steps.size).to eq(1)
    end

    it "accepts all options" do
      dynamic = ->(prev) { { extra: "value" } }
      transform = ->(result) { result.to_s }

      pipeline.add_step(:search,
        query: "Ruby",
        dynamic_args: dynamic,
        transform: transform,
        name: "custom"
      )

      step = pipeline.steps.first
      expect(step.static_args).to eq({ query: "Ruby" })
      expect(step.dynamic_args).to eq(dynamic)
      expect(step.transform).to eq(transform)
      expect(step.name).to eq("custom")
    end
  end

  describe "#insert_step" do
    let(:pipeline) { described_class.new(tools) }

    it "inserts at specific position" do
      pipeline.step(:search, query: "Ruby")
      pipeline.step(:extract, pattern: "Ruby")
      pipeline.insert_step(1, :visit, static_args: { url: "http://example.com" })

      expect(pipeline.steps[1].tool_name).to eq("visit")
      expect(pipeline.steps.size).to eq(3)
    end
  end

  describe "#remove_step" do
    let(:pipeline) { described_class.new(tools) }

    it "removes by index" do
      pipeline.step(:search, query: "Ruby")
      pipeline.step(:visit, url: "http://example.com")

      pipeline.remove_step(0)
      expect(pipeline.steps.size).to eq(1)
      expect(pipeline.steps.first.tool_name).to eq("visit")
    end

    it "removes by name" do
      pipeline.step(:search, name: "find", query: "Ruby")
      pipeline.step(:visit, url: "http://example.com")

      pipeline.remove_step("find")
      expect(pipeline.steps.size).to eq(1)
    end
  end

  describe "#clear_steps" do
    it "removes all steps" do
      pipeline = described_class.build(tools) do
        step :search, query: "Ruby"
        step :visit, url: "http://example.com"
      end

      pipeline.clear_steps
      expect(pipeline.empty?).to be true
    end
  end

  describe "#run" do
    it "executes single step pipeline" do
      pipeline = described_class.build(tools) do
        step :search, query: "Ruby"
      end

      result = pipeline.run
      expect(result).to be_a(Smolagents::ToolResult)
      expect(result.count).to eq(2)
    end

    it "chains multiple steps with dynamic args" do
      pipeline = described_class.build(tools) do
        step :search, query: "Ruby"
        step :visit do |prev|
          { url: prev.first[:link] }
        end
      end

      result = pipeline.run
      expect(result.to_s).to include("ruby-lang.org")
    end

    it "handles initial input" do
      allow(search_tool).to receive(:call).with(query: "initial input").and_return([{ title: "Result" }])

      pipeline = described_class.build(tools) do
        step :search do |input|
          { query: input.to_s }
        end
      end

      result = pipeline.run("initial input")
      expect(result.first[:title]).to eq("Result")
    end

    it "wraps non-ToolResult outputs" do
      pipeline = described_class.build(tools) do
        step :search, query: "Ruby"
      end

      result = pipeline.run
      expect(result).to be_a(Smolagents::ToolResult)
    end

    it "is aliased as call" do
      pipeline = described_class.new(tools)
      pipeline.step(:search, query: "Ruby")
      expect(pipeline.call).to be_a(Smolagents::ToolResult)
    end
  end

  describe "#run_with_details" do
    it "returns ExecutionResult with timing" do
      pipeline = described_class.build(tools) do
        step :search, query: "Ruby"
      end

      result = pipeline.run_with_details
      expect(result).to be_a(Smolagents::ToolPipeline::ExecutionResult)
      expect(result.duration_ms).to be > 0
    end

    it "includes step-by-step details" do
      pipeline = described_class.build(tools) do
        step :search, name: "find_ruby", query: "Ruby"
        step :visit do |prev|
          { url: prev.first[:link] }
        end
      end

      result = pipeline.run_with_details
      expect(result.steps.size).to eq(2)
      expect(result.steps.first[:step]).to eq("find_ruby")
      expect(result.steps.first[:success]).to be true
    end

    it "captures errors" do
      failing_tool = instance_double("FailingTool")
      allow(failing_tool).to receive(:name).and_return("failing")
      allow(failing_tool).to receive(:call).and_raise(StandardError, "Tool failed")

      pipeline = described_class.new(tools.merge("failing" => failing_tool))
      pipeline.step(:search, query: "Ruby")
      pipeline.step(:failing)

      result = pipeline.run_with_details
      expect(result.success?).to be false
      expect(result.steps.last[:error]).to eq("Tool failed")
    end

    it "provides summary" do
      pipeline = described_class.build(tools) do
        step :search, query: "Ruby"
      end

      result = pipeline.run_with_details
      summary = result.summary
      expect(summary).to include("Pipeline completed")
      expect(summary).to include("1 steps")
    end
  end

  describe "#empty?" do
    it "returns true for empty pipeline" do
      pipeline = described_class.new(tools)
      expect(pipeline.empty?).to be true
    end

    it "returns false when steps exist" do
      pipeline = described_class.build(tools) { step :search, query: "Ruby" }
      expect(pipeline.empty?).to be false
    end
  end

  describe "#size" do
    it "returns number of steps" do
      pipeline = described_class.build(tools) do
        step :search, query: "Ruby"
        step :visit, url: "http://example.com"
      end

      expect(pipeline.size).to eq(2)
      expect(pipeline.length).to eq(2)
    end
  end

  describe "#describe" do
    it "describes the pipeline" do
      pipeline = described_class.build(tools, name: "Test") do
        step :search, query: "Ruby"
        step :visit do |prev|
          { url: prev.first[:link] }
        end
      end

      description = pipeline.describe
      expect(description).to include("Pipeline: Test")
      expect(description).to include("1. search(query)")
      expect(description).to include("2. visit [dynamic]")
    end
  end

  describe "#+" do
    it "combines two pipelines" do
      pipeline1 = described_class.build(tools) { step :search, query: "Ruby" }
      pipeline2 = described_class.build(tools) { step :visit, url: "http://example.com" }

      combined = pipeline1 + pipeline2
      expect(combined.size).to eq(2)
      expect(combined.steps.first.tool_name).to eq("search")
      expect(combined.steps.last.tool_name).to eq("visit")
    end
  end

  describe "#dup" do
    it "creates a copy" do
      original = described_class.build(tools) { step :search, query: "Ruby" }
      copy = original.dup

      copy.step(:visit, url: "http://example.com")

      expect(original.size).to eq(1)
      expect(copy.size).to eq(2)
    end
  end

  describe "error handling" do
    it "returns error result for unknown tools" do
      pipeline = described_class.build(tools) do
        step :unknown_tool, param: "value"
      end

      result = pipeline.run
      expect(result.error?).to be true
      expect(result.metadata[:error]).to include("Unknown tool: unknown_tool")
    end

    it "includes error details in execution result" do
      pipeline = described_class.build(tools) do
        step :unknown_tool, param: "value"
      end

      result = pipeline.run_with_details
      expect(result.success?).to be false
      expect(result.steps.first[:error]).to include("Unknown tool")
    end
  end

  describe "complex workflows" do
    it "handles multi-step extraction pipeline" do
      pipeline = described_class.build(tools) do
        step :search, query: "Ruby"
        step :visit do |prev|
          { url: prev.first[:link] }
        end
        step :extract, pattern: "<title>(.*?)</title>" do |prev|
          { text: prev.to_s }
        end
      end

      result = pipeline.run
      expect(result.first).to include("ruby-lang.org")
    end

    it "handles transform-only pipelines" do
      data = [1, 2, 3, 4, 5]
      pipeline = described_class.new(tools)

      pipeline.transform("double") { |input| input.map { |n| n * 2 } }
      pipeline.transform("filter") { |input| input.select { |n| n > 5 } }

      result = pipeline.run(data)
      expect(result.to_a).to eq([6, 8, 10])
    end
  end

  describe "Step data object" do
    it "has a label that defaults to tool_name" do
      step = Smolagents::ToolPipeline::Step.new(tool_name: "search")
      expect(step.label).to eq("search")
    end

    it "uses name for label when provided" do
      step = Smolagents::ToolPipeline::Step.new(tool_name: "search", name: "find_items")
      expect(step.label).to eq("find_items")
    end
  end

  describe "ExecutionResult data object" do
    let(:output) { Smolagents::ToolResult.new([1, 2, 3], tool_name: "test") }
    let(:steps) { [{ step: "test", duration_ms: 10, success: true }] }

    it "provides access to output" do
      result = Smolagents::ToolPipeline::ExecutionResult.new(
        output: output,
        steps: steps,
        duration_ms: 10
      )

      expect(result.output).to eq(output)
      expect(result.to_tool_result).to eq(output)
    end

    it "defaults success to true" do
      result = Smolagents::ToolPipeline::ExecutionResult.new(
        output: output,
        steps: steps,
        duration_ms: 10
      )

      expect(result.success?).to be true
    end
  end
end
