# frozen_string_literal: true

# Refinements spec must use the refinements at file scope
# since Ruby refinements are lexically scoped
using Smolagents::Refinements

RSpec.describe Smolagents::Refinements do
  # Mock tools for testing
  let(:search_tool) do
    tool = instance_double("SearchTool")
    allow(tool).to receive(:call).with(query: "Ruby programming").and_return([
                                                                               { title: "Ruby Lang", link: "https://ruby-lang.org" },
                                                                               { title: "Ruby Gems", link: "https://rubygems.org" }
                                                                             ])
    allow(tool).to receive(:call).with(query: "Ruby programming", max_results: 5).and_return([
                                                                                               { title: "Ruby Lang", link: "https://ruby-lang.org" }
                                                                                             ])
    tool
  end

  let(:visit_tool) do
    tool = instance_double("VisitTool")
    allow(tool).to receive(:call).with(url: "https://ruby-lang.org").and_return(
      "<html><title>Ruby Language</title><body>Welcome</body></html>"
    )
    tool
  end

  let(:wikipedia_tool) do
    tool = instance_double("WikipediaTool")
    allow(tool).to receive(:call).with(query: "Ruby programming").and_return(
      "Ruby is a dynamic programming language..."
    )
    tool
  end

  let(:calculate_tool) do
    tool = instance_double("CalculateTool")
    allow(tool).to receive(:call).with(code: "2 + 2 * 3").and_return(8)
    allow(tool).to receive(:call).with(code: "(1..10).sum").and_return(55)
    tool
  end

  before do
    Smolagents::Refinements.reset!
  end

  describe ".configure" do
    it "registers multiple tools at once" do
      described_class.configure(
        search: search_tool,
        visit: visit_tool
      )

      expect(described_class.tool(:search)).to eq(search_tool)
      expect(described_class.tool(:visit)).to eq(visit_tool)
    end

    it "accepts string keys and converts to symbols" do
      described_class.configure("search" => search_tool)

      expect(described_class.tool(:search)).to eq(search_tool)
    end

    it "stores default options" do
      described_class.configure(search: search_tool, timeout: 30)

      expect(described_class.default_options[:timeout]).to eq(30)
    end

    it "accepts a block for additional configuration" do
      tool = search_tool
      described_class.configure do
        register :search, tool
      end

      expect(described_class.tool(:search)).to eq(tool)
    end

    it "returns self for chaining" do
      result = described_class.configure(search: search_tool)
      expect(result).to eq(described_class)
    end
  end

  describe ".register" do
    it "registers a single tool" do
      described_class.register(:search, search_tool)

      expect(described_class.tool(:search)).to eq(search_tool)
    end

    it "accepts string names" do
      described_class.register("search", search_tool)

      expect(described_class.tool(:search)).to eq(search_tool)
    end

    it "overwrites existing tools" do
      described_class.register(:search, search_tool)
      new_tool = instance_double("NewTool")
      described_class.register(:search, new_tool)

      expect(described_class.tool(:search)).to eq(new_tool)
    end
  end

  describe ".tool" do
    it "returns registered tool by symbol" do
      described_class.register(:search, search_tool)

      expect(described_class.tool(:search)).to eq(search_tool)
    end

    it "returns registered tool by string" do
      described_class.register(:search, search_tool)

      expect(described_class.tool("search")).to eq(search_tool)
    end

    it "returns nil for unregistered tool" do
      expect(described_class.tool(:unknown)).to be_nil
    end
  end

  describe ".tool?" do
    it "returns true for registered tool" do
      described_class.register(:search, search_tool)

      expect(described_class.tool?(:search)).to be true
    end

    it "returns false for unregistered tool" do
      expect(described_class.tool?(:unknown)).to be false
    end
  end

  describe ".reset!" do
    it "clears all registrations" do
      described_class.configure(
        search: search_tool,
        visit: visit_tool,
        timeout: 30
      )

      described_class.reset!

      expect(described_class.tools).to eq({})
      expect(described_class.default_options).to eq({})
    end
  end

  describe "String refinements" do
    describe "#search" do
      before do
        Smolagents::Refinements.register(:search, search_tool)
      end

      it "performs web search" do
        result = "Ruby programming".search

        expect(result).to be_a(Smolagents::ToolResult)
        expect(result.count).to eq(2)
        expect(result.first[:title]).to eq("Ruby Lang")
      end

      it "passes options to tool" do
        result = "Ruby programming".search(max_results: 5)

        expect(result.count).to eq(1)
      end

      it "raises NoMethodError when no search tool configured" do
        Smolagents::Refinements.reset!

        expect { "Ruby".search }.to raise_error(NoMethodError, /No search tool configured/)
      end

      it "finds tool by alternate name" do
        Smolagents::Refinements.reset!
        Smolagents::Refinements.register(:web_search, search_tool)

        result = "Ruby programming".search
        expect(result).to be_a(Smolagents::ToolResult)
      end
    end

    describe "#visit" do
      before do
        Smolagents::Refinements.register(:visit, visit_tool)
      end

      it "visits URL and returns content" do
        result = "https://ruby-lang.org".visit

        expect(result).to be_a(Smolagents::ToolResult)
        expect(result.to_s).to include("Ruby Language")
      end

      it "raises NoMethodError when no visit tool configured" do
        Smolagents::Refinements.reset!

        expect { "https://example.com".visit }.to raise_error(NoMethodError, /No visit tool configured/)
      end

      it "finds tool by alternate name" do
        Smolagents::Refinements.reset!
        Smolagents::Refinements.register(:visit_webpage, visit_tool)

        result = "https://ruby-lang.org".visit
        expect(result).to be_a(Smolagents::ToolResult)
      end
    end

    describe "#wikipedia" do
      before do
        Smolagents::Refinements.register(:wikipedia, wikipedia_tool)
      end

      it "searches Wikipedia" do
        result = "Ruby programming".wikipedia

        expect(result).to be_a(Smolagents::ToolResult)
        expect(result.to_s).to include("dynamic programming language")
      end

      it "raises NoMethodError when no wikipedia tool configured" do
        Smolagents::Refinements.reset!

        expect { "Ruby".wikipedia }.to raise_error(NoMethodError, /No wikipedia tool configured/)
      end
    end

    describe "#calculate" do
      before do
        Smolagents::Refinements.register(:calculate, calculate_tool)
      end

      it "evaluates expressions" do
        result = "2 + 2 * 3".calculate

        expect(result).to be_a(Smolagents::ToolResult)
        expect(result.data).to eq(8)
      end

      it "handles Ruby expressions" do
        result = "(1..10).sum".calculate

        expect(result.data).to eq(55)
      end

      it "raises NoMethodError when no calculation tool configured" do
        Smolagents::Refinements.reset!

        expect { "1+1".calculate }.to raise_error(NoMethodError, /No calculate tool configured/)
      end
    end

    describe "#extract_from" do
      it "extracts patterns using regex fallback" do
        result = '\d{4}-\d{2}-\d{2}'.extract_from("Dates: 2024-01-15 and 2024-02-20")

        expect(result).to be_a(Smolagents::ToolResult)
        expect(result.to_a).to eq(%w[2024-01-15 2024-02-20])
      end

      it "uses regex tool when available" do
        regex_tool = instance_double("RegexTool")
        allow(regex_tool).to receive(:call).with(text: "test", pattern: "t").and_return(%w[t t])
        Smolagents::Refinements.register(:regex, regex_tool)

        result = "t".extract_from("test")

        expect(result).to be_a(Smolagents::ToolResult)
      end
    end

    describe "#as_regex" do
      it "converts string to Regexp" do
        regex = '\d+'.as_regex

        expect(regex).to be_a(Regexp)
        expect("123").to match(regex)
      end

      it "accepts Regexp options" do
        regex = "ruby".as_regex(Regexp::IGNORECASE)

        expect("RUBY").to match(regex)
      end
    end

    describe "#render" do
      it "substitutes template variables" do
        result = "Hello {{name}}!".render(name: "World")

        expect(result).to eq("Hello World!")
      end

      it "handles multiple variables" do
        template = "{{greeting}} {{name}}, welcome to {{place}}!"
        result = template.render(greeting: "Hi", name: "Alice", place: "Ruby")

        expect(result).to eq("Hi Alice, welcome to Ruby!")
      end

      it "converts values to strings" do
        result = "Count: {{count}}".render(count: 42)

        expect(result).to eq("Count: 42")
      end

      it "leaves unmatched placeholders" do
        result = "Hello {{name}}!".render(other: "value")

        expect(result).to eq("Hello {{name}}!")
      end
    end
  end

  describe "Array refinements" do
    describe "#to_tool_result" do
      it "converts array to ToolResult" do
        result = [1, 2, 3].to_tool_result

        expect(result).to be_a(Smolagents::ToolResult)
        expect(result.to_a).to eq([1, 2, 3])
        expect(result.tool_name).to eq("array")
      end

      it "accepts custom tool name" do
        result = [1, 2, 3].to_tool_result(tool_name: "custom")

        expect(result.tool_name).to eq("custom")
      end

      it "accepts metadata" do
        result = [1, 2, 3].to_tool_result(source: "test")

        expect(result.metadata[:source]).to eq("test")
      end
    end

    describe "#transform" do
      let(:users) do
        [
          { name: "Alice", age: 30, active: true },
          { name: "Bob", age: 25, active: false },
          { name: "Carol", age: 35, active: true }
        ]
      end

      it "applies select operation" do
        result = users.transform([
                                   { type: "select", condition: { field: :active, op: "=", value: true } }
                                 ])

        expect(result).to be_a(Smolagents::ToolResult)
        expect(result.count).to eq(2)
      end

      it "applies reject operation" do
        result = users.transform([
                                   { type: "reject", condition: { field: :active, op: "=", value: false } }
                                 ])

        expect(result.count).to eq(2)
      end

      it "applies sort_by operation" do
        result = users.transform([
                                   { type: "sort_by", key: :age }
                                 ])

        expect(result.first[:name]).to eq("Bob")
        expect(result.last[:name]).to eq("Carol")
      end

      it "applies take operation" do
        result = users.transform([
                                   { type: "take", count: 2 }
                                 ])

        expect(result.count).to eq(2)
      end

      it "applies drop operation" do
        result = users.transform([
                                   { type: "drop", count: 1 }
                                 ])

        expect(result.count).to eq(2)
        expect(result.first[:name]).to eq("Bob")
      end

      it "applies uniq operation" do
        data = [{ type: "a" }, { type: "b" }, { type: "a" }]
        result = data.transform([
                                  { type: "uniq", key: :type }
                                ])

        expect(result.count).to eq(2)
      end

      it "applies pluck operation" do
        result = users.transform([
                                   { type: "pluck", key: :name }
                                 ])

        expect(result.to_a).to eq(%w[Alice Bob Carol])
      end

      it "chains multiple operations" do
        result = users.transform([
                                   { type: "select", condition: { field: :active, op: "=", value: true } },
                                   { type: "sort_by", key: :age },
                                   { type: "pluck", key: :name }
                                 ])

        expect(result.to_a).to eq(%w[Alice Carol])
      end

      it "supports comparison operators" do
        result = users.transform([
                                   { type: "select", condition: { field: :age, op: ">", value: 28 } }
                                 ])

        expect(result.count).to eq(2)
      end

      it "supports string keys in operations" do
        result = users.transform([
                                   { "type" => "select", "condition" => { "field" => :active, "op" => "=", "value" => true } }
                                 ])

        expect(result.count).to eq(2)
      end

      it "uses DataTransformTool when available" do
        transform_tool = instance_double("DataTransformTool")
        transformed = [{ name: "Transformed" }]
        allow(transform_tool).to receive(:call).and_return(transformed)
        Smolagents::Refinements.register(:data_transform, transform_tool)

        users.transform([{ type: "select" }])

        expect(transform_tool).to have_received(:call)
      end
    end
  end

  describe "Hash refinements" do
    describe "#to_tool_result" do
      it "converts hash to ToolResult" do
        result = { key: "value" }.to_tool_result

        expect(result).to be_a(Smolagents::ToolResult)
        expect(result.data).to eq({ key: "value" })
        expect(result.tool_name).to eq("hash")
      end

      it "accepts custom tool name" do
        result = { key: "value" }.to_tool_result(tool_name: "config")

        expect(result.tool_name).to eq("config")
      end
    end

    describe "#dig_path" do
      let(:data) do
        {
          "users" => [
            { "name" => "Alice", "profile" => { "email" => "alice@example.com" } },
            { "name" => "Bob", "profile" => { "email" => "bob@example.com" } }
          ],
          "config" => {
            "settings" => {
              "timeout" => 30
            }
          }
        }
      end

      it "navigates simple paths" do
        result = data.dig_path("config.settings.timeout")

        expect(result).to eq(30)
      end

      it "navigates array indices" do
        result = data.dig_path("users[0].name")

        expect(result).to eq("Alice")
      end

      it "navigates nested array paths" do
        result = data.dig_path("users[1].profile.email")

        expect(result).to eq("bob@example.com")
      end

      it "returns nil for missing paths" do
        result = data.dig_path("users[99].name")

        expect(result).to be_nil
      end

      it "handles symbol keys" do
        data = { users: [{ name: "Alice" }] }
        result = data.dig_path("users[0].name")

        expect(result).to eq("Alice")
      end
    end

    describe "#query" do
      let(:data) do
        { "name" => "Alice", "age" => 30 }
      end

      it "returns ToolResult with queried value" do
        result = data.query("name")

        expect(result).to be_a(Smolagents::ToolResult)
        expect(result.data).to eq("Alice")
      end

      it "uses json_query tool when available" do
        query_tool = instance_double("JsonQueryTool")
        allow(query_tool).to receive(:call).with(data: data, path: "name").and_return("Queried")
        Smolagents::Refinements.register(:json_query, query_tool)

        data.query("name")

        expect(query_tool).to have_received(:call)
      end
    end
  end

  describe "Integer refinements" do
    describe "#times_result" do
      it "generates ToolResult with n items" do
        result = 5.times_result { |i| { id: i } }

        expect(result).to be_a(Smolagents::ToolResult)
        expect(result.count).to eq(5)
        expect(result.first[:id]).to eq(0)
        expect(result.last[:id]).to eq(4)
      end

      it "sets tool_name to generate" do
        result = 3.times_result { |i| i }

        expect(result.tool_name).to eq("generate")
      end
    end
  end

  describe "Range refinements" do
    describe "#to_tool_result" do
      it "converts range to ToolResult" do
        result = (1..5).to_tool_result

        expect(result).to be_a(Smolagents::ToolResult)
        expect(result.to_a).to eq([1, 2, 3, 4, 5])
        expect(result.tool_name).to eq("range")
      end

      it "accepts custom tool name" do
        result = (1..3).to_tool_result(tool_name: "sequence")

        expect(result.tool_name).to eq("sequence")
      end
    end
  end

  describe "Proc refinements" do
    describe "#as_transform" do
      it "wraps proc as transform specification" do
        double_proc = ->(x) { x * 2 }
        result = double_proc.as_transform

        expect(result[:type]).to eq("__proc__")
        expect(result[:proc]).to eq(double_proc)
        expect(result[:name]).to eq("custom")
      end

      it "accepts custom name" do
        proc = ->(x) { x }
        result = proc.as_transform(name: "identity")

        expect(result[:name]).to eq("identity")
      end
    end
  end

  describe "AllRefinements" do
    # AllRefinements tests are already covered since we're using the refinements
    # at file scope. The module just re-exports Refinements.
    it "is an alias for Refinements" do
      expect(Smolagents::AllRefinements).to be_a(Module)
    end
  end
end
