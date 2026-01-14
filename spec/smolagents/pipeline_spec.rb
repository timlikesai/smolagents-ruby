RSpec.describe Smolagents::Pipeline do
  # Mock tool for testing
  let(:search_tool) do
    Smolagents::Tools.define_tool(
      "search",
      description: "Search for something",
      inputs: { "query" => { type: "string", description: "Search query" } },
      output_type: "array"
    ) { |query:| [{ title: "Result 1", url: "http://example.com/1", query: }, { title: "Result 2", url: "http://example.com/2", query: }] }
  end

  let(:visit_tool) do
    Smolagents::Tools.define_tool(
      "visit",
      description: "Visit a URL",
      inputs: { "url" => { type: "string", description: "URL to visit" } },
      output_type: "object"
    ) { |url:| { content: "Content from #{url}", url: } }
  end

  let(:summarize_tool) do
    Smolagents::Tools.define_tool(
      "summarize",
      description: "Summarize text",
      inputs: { "text" => { type: "string", description: "Text to summarize" } },
      output_type: "string"
    ) { |text:| "Summary: #{text[0..50]}..." }
  end

  before do
    # Register mock tools
    allow(Smolagents::Tools).to receive(:get).with("search").and_return(search_tool)
    allow(Smolagents::Tools).to receive(:get).with("visit").and_return(visit_tool)
    allow(Smolagents::Tools).to receive(:get).with("summarize").and_return(summarize_tool)
    allow(Smolagents::Tools).to receive(:get).with("unknown").and_return(nil)
  end

  describe "#initialize" do
    it "creates an empty pipeline" do
      pipeline = described_class.new

      expect(pipeline.steps).to eq([])
      expect(pipeline).to be_empty
    end

    it "accepts initial steps" do
      step = Smolagents::Pipeline::Step::Call.new(:search, { query: "test" }, nil)
      pipeline = described_class.new(steps: [step])

      expect(pipeline.steps).to eq([step])
      expect(pipeline.length).to eq(1)
    end
  end

  describe "#call / #then" do
    it "adds a call step with static args" do
      pipeline = described_class.new.call(:search, query: "test")

      expect(pipeline.length).to eq(1)
      expect(pipeline.steps.first).to be_a(Smolagents::Pipeline::Step::Call)
      expect(pipeline.steps.first.tool_name).to eq(:search)
    end

    it "adds a call step with dynamic block" do
      pipeline = described_class.new
                                .call(:search, query: "initial")
                                .then(:visit) { |prev| { url: prev.first[:url] } }

      expect(pipeline.length).to eq(2)
      expect(pipeline.steps.last.dynamic_block).not_to be_nil
    end

    it "is immutable - returns new pipeline" do
      pipeline1 = described_class.new
      pipeline2 = pipeline1.call(:search, query: "test")

      expect(pipeline1.length).to eq(0)
      expect(pipeline2.length).to eq(1)
      expect(pipeline1).not_to eq(pipeline2)
    end
  end

  describe "#transform" do
    it "adds a custom transform step" do
      pipeline = described_class.new
                                .call(:search, query: "test")
                                .transform { |r| r.data.map { |item| item[:title] } }

      expect(pipeline.length).to eq(2)
      expect(pipeline.steps.last).to be_a(Smolagents::Pipeline::Step::Transform)
      expect(pipeline.steps.last.operation).to eq(:custom)
    end
  end

  describe "chainable transforms" do
    it "supports select" do
      pipeline = described_class.new
                                .call(:search, query: "test")
                                .select { |item| item[:title].include?("1") }

      expect(pipeline.steps.last.operation).to eq(:select)
    end

    it "supports map" do
      pipeline = described_class.new
                                .call(:search, query: "test")
                                .map { |item| item[:title] }

      expect(pipeline.steps.last.operation).to eq(:map)
    end

    it "supports take" do
      pipeline = described_class.new
                                .call(:search, query: "test")
                                .take(1)

      expect(pipeline.steps.last.operation).to eq(:take)
      expect(pipeline.steps.last.args).to eq([1])
    end

    it "supports pluck" do
      pipeline = described_class.new
                                .call(:search, query: "test")
                                .pluck(:title)

      expect(pipeline.steps.last.operation).to eq(:pluck)
      expect(pipeline.steps.last.args).to eq([:title])
    end

    it "supports chaining multiple transforms" do
      pipeline = described_class.new
                                .call(:search, query: "test")
                                .select { |item| item[:title] }
                                .map { |item| item[:url] }
                                .take(1)

      expect(pipeline.length).to eq(4)
    end
  end

  describe "#run" do
    it "executes a single tool" do
      pipeline = described_class.new.call(:search, query: "Ruby")
      result = pipeline.run

      expect(result).to be_a(Smolagents::ToolResult)
      expect(result.data).to be_an(Array)
      expect(result.data.first[:query]).to eq("Ruby")
    end

    it "executes with input args" do
      pipeline = described_class.new.call(:search, query: :input)
      result = pipeline.run(input: "Ruby 4.0")

      expect(result.data.first[:query]).to eq("Ruby 4.0")
    end

    it "chains multiple tools" do
      pipeline = described_class.new
                                .call(:search, query: "Ruby")
                                .then(:visit) { |prev| { url: prev.data.first[:url] } }

      result = pipeline.run

      expect(result.data[:url]).to eq("http://example.com/1")
      expect(result.data[:content]).to include("http://example.com/1")
    end

    it "applies transforms between tools" do
      pipeline = described_class.new
                                .call(:search, query: "Ruby")
                                .take(1)
                                .then(:visit) { |prev| { url: prev.data.first[:url] } }

      result = pipeline.run

      expect(result.data[:url]).to eq("http://example.com/1")
    end

    it "raises error for unknown tool" do
      pipeline = described_class.new.call(:unknown, query: "test")

      expect { pipeline.run }.to raise_error(ArgumentError, /Unknown tool: unknown/)
    end
  end

  describe "#as_tool" do
    it "converts pipeline to a tool" do
      pipeline = described_class.new
                                .call(:search, query: :input)
                                .take(1)

      tool = pipeline.as_tool("quick_search", "Search and return first result")

      expect(tool).to be_a(Smolagents::Tool)
      expect(tool.name).to eq("quick_search")
      expect(tool.description).to eq("Search and return first result")
    end

    it "executes correctly as a tool" do
      pipeline = described_class.new
                                .call(:search, query: :input)
                                .pluck(:title)

      tool = pipeline.as_tool("title_search", "Search and return titles")
      result = tool.call(input: "Ruby")

      expect(result.data).to eq(["Result 1", "Result 2"])
    end

    it "accepts custom input specification" do
      pipeline = described_class.new.call(:search, query: :query)
      tool = pipeline.as_tool(
        "custom_search",
        "Custom search",
        inputs: { "query" => { type: "string", description: "Search query" } }
      )

      expect(tool.inputs[:query][:type]).to eq("string")
    end
  end

  describe "#inspect" do
    it "shows pipeline structure" do
      pipeline = described_class.new
                                .call(:search, query: "test")
                                .select { |x| x }
                                .then(:visit) { |r| { url: r.first[:url] } }

      expect(pipeline.inspect).to include("call(:search)")
      expect(pipeline.inspect).to include("select")
      expect(pipeline.inspect).to include("call(:visit)")
    end
  end

  describe "Step::Call" do
    describe "#resolve_args" do
      let(:prev_result) do
        Smolagents::ToolResult.new(
          [{ url: "http://example.com", title: "Test" }],
          tool_name: "search"
        )
      end

      it "resolves :input to prev data" do
        step = Smolagents::Pipeline::Step::Call.new(:visit, { url: :input }, nil)
        args = step.send(:resolve_args, prev_result)

        expect(args[:url]).to eq(prev_result.data)
      end

      it "resolves :prev to prev data" do
        step = Smolagents::Pipeline::Step::Call.new(:visit, { url: :prev }, nil)
        args = step.send(:resolve_args, prev_result)

        expect(args[:url]).to eq(prev_result.data)
      end

      it "passes literal values through" do
        step = Smolagents::Pipeline::Step::Call.new(:visit, { url: "http://literal.com" }, nil)
        args = step.send(:resolve_args, prev_result)

        expect(args[:url]).to eq("http://literal.com")
      end

      it "merges dynamic block results" do
        dynamic = ->(prev) { { url: prev.first[:url] } }
        step = Smolagents::Pipeline::Step::Call.new(:visit, {}, dynamic)
        args = step.send(:resolve_args, prev_result)

        expect(args[:url]).to eq("http://example.com")
      end
    end
  end

  describe "Step::Transform" do
    let(:prev_result) do
      Smolagents::ToolResult.new(
        [{ value: 1 }, { value: 2 }, { value: 3 }],
        tool_name: "test"
      )
    end

    it "executes custom transforms" do
      step = Smolagents::Pipeline::Step::Transform.new(:custom, ->(r) { r.data.sum { |x| x[:value] } }, [])
      result = step.execute(prev_result, registry: nil)

      expect(result.data).to eq(6)
    end

    it "executes select" do
      step = Smolagents::Pipeline::Step::Transform.new(:select, ->(x) { x[:value] > 1 }, [])
      result = step.execute(prev_result, registry: nil)

      expect(result.data.length).to eq(2)
    end

    it "executes take" do
      step = Smolagents::Pipeline::Step::Transform.new(:take, nil, [2])
      result = step.execute(prev_result, registry: nil)

      expect(result.data.length).to eq(2)
    end

    it "executes pluck" do
      step = Smolagents::Pipeline::Step::Transform.new(:pluck, nil, [:value])
      result = step.execute(prev_result, registry: nil)

      expect(result.data).to eq([1, 2, 3])
    end
  end
end

RSpec.describe Smolagents do
  describe ".pipeline" do
    it "returns a new empty pipeline" do
      pipeline = described_class.pipeline

      expect(pipeline).to be_a(Smolagents::Pipeline)
      expect(pipeline).to be_empty
    end
  end

  describe ".run" do
    let(:search_tool) do
      Smolagents::Tools.define_tool(
        "search",
        description: "Search",
        inputs: { "query" => { type: "string", description: "Query" } },
        output_type: "array"
      ) { |query:| [{ title: query }] }
    end

    before do
      allow(Smolagents::Tools).to receive(:get).with("search").and_return(search_tool)
    end

    it "returns a pipeline with the tool call" do
      pipeline = described_class.run(:search, query: "test")

      expect(pipeline).to be_a(Smolagents::Pipeline)
      expect(pipeline.length).to eq(1)
    end

    it "can be chained and executed" do
      result = described_class.run(:search, query: "Ruby")
                              .pluck(:title)
                              .run

      expect(result.data).to eq(["Ruby"])
    end
  end
end
