RSpec.describe Smolagents::Executors::Executor::ToolRegistration do
  let(:test_executor) do
    Class.new(Smolagents::Executor) do
      include Smolagents::Executors::Executor::ToolRegistration

      # rubocop:disable Lint/MissingSuper -- test double doesn't need parent initialization
      def initialize
        initialize_tool_registration
      end
      # rubocop:enable Lint/MissingSuper

      def supports?(language)
        language == :ruby
      end
    end
  end

  let(:executor) { test_executor.new }

  describe "#send_tools" do
    it "registers a single tool" do
      tool = instance_double(Smolagents::Tool)
      executor.send_tools(search: tool)

      expect(executor.tools["search"]).to eq(tool)
    end

    it "registers multiple tools" do
      tool1 = instance_double(Smolagents::Tool)
      tool2 = instance_double(Smolagents::Tool)
      tool3 = instance_double(Smolagents::Tool)

      executor.send_tools(
        search: tool1,
        web: tool2,
        calculate: tool3
      )

      expect(executor.tools["search"]).to eq(tool1)
      expect(executor.tools["web"]).to eq(tool2)
      expect(executor.tools["calculate"]).to eq(tool3)
    end

    it "handles symbol keys" do
      tool = instance_double(Smolagents::Tool)
      executor.send_tools(my_tool: tool)

      expect(executor.tools["my_tool"]).to eq(tool)
    end

    it "handles string keys" do
      tool = instance_double(Smolagents::Tool)
      executor.send_tools("search" => tool)

      expect(executor.tools["search"]).to eq(tool)
    end

    it "accumulates tools on multiple calls" do
      tool1 = instance_double(Smolagents::Tool)
      tool2 = instance_double(Smolagents::Tool)

      executor.send_tools(search: tool1)
      executor.send_tools(web: tool2)

      expect(executor.tools).to include("search", "web")
    end

    it "overwrites existing tools" do
      tool1 = instance_double(Smolagents::Tool)
      tool2 = instance_double(Smolagents::Tool)

      executor.send_tools(search: tool1)
      executor.send_tools(search: tool2)

      expect(executor.tools["search"]).to eq(tool2)
    end

    it "raises ArgumentError for dangerous method names" do
      tool = instance_double(Smolagents::Tool)

      # 'eval' is a dangerous method
      expect do
        executor.send_tools(eval: tool)
      end.to raise_error(ArgumentError, /dangerous/)
    end

    it "blocks __send__" do
      tool = instance_double(Smolagents::Tool)

      expect do
        executor.send_tools("__send__" => tool)
      end.to raise_error(ArgumentError, /dangerous/)
    end

    it "blocks system" do
      tool = instance_double(Smolagents::Tool)

      expect do
        executor.send_tools(system: tool)
      end.to raise_error(ArgumentError, /dangerous/)
    end

    it "accepts safe method names" do
      tool = instance_double(Smolagents::Tool)

      # These should be fine
      executor.send_tools(
        search: tool,
        web_search: tool,
        my_custom_tool: tool
      )

      expect(executor.tools.size).to eq(3)
    end
  end

  describe "#send_variables" do
    it "registers a single variable" do
      executor.send_variables(x: 42)

      expect(executor.variables["x"]).to eq(42)
    end

    it "registers multiple variables" do
      executor.send_variables(
        x: 42,
        name: "Alice",
        data: [1, 2, 3]
      )

      expect(executor.variables["x"]).to eq(42)
      expect(executor.variables["name"]).to eq("Alice")
      expect(executor.variables["data"]).to eq([1, 2, 3])
    end

    it "handles symbol keys" do
      executor.send_variables(result: 100)

      expect(executor.variables["result"]).to eq(100)
    end

    it "handles string keys" do
      executor.send_variables("value" => 50)

      expect(executor.variables["value"]).to eq(50)
    end

    it "accumulates variables on multiple calls" do
      executor.send_variables(x: 1)
      executor.send_variables(y: 2)

      expect(executor.variables).to include("x", "y")
    end

    it "overwrites existing variables" do
      executor.send_variables(x: 10)
      executor.send_variables(x: 20)

      expect(executor.variables["x"]).to eq(20)
    end

    it "stores complex values" do
      complex = { nested: { data: [1, 2, 3] }, timestamp: Time.now }
      executor.send_variables(data: complex)

      expect(executor.variables["data"]).to eq(complex)
    end

    it "stores nil values" do
      executor.send_variables(nothing: nil)

      expect(executor.variables["nothing"]).to be_nil
      expect(executor.variables).to include("nothing")
    end

    it "does not validate variable names" do
      # Variables don't have the same restrictions as tools
      executor.send_variables(
        "class" => "value",
        "eval" => "data",
        "__send__" => "test"
      )

      expect(executor.variables.size).to eq(3)
    end
  end

  describe "initialization" do
    it "initializes empty tools hash" do
      expect(executor.tools).to eq({})
    end

    it "initializes empty variables hash" do
      expect(executor.variables).to eq({})
    end

    it "are independent hashes" do
      executor.send_tools(search: instance_double(Smolagents::Tool))
      executor.send_variables(x: 42)

      expect(executor.tools.keys).to eq(["search"])
      expect(executor.variables.keys).to eq(["x"])
    end
  end

  describe "tools and variables coexistence" do
    it "both can be registered for same executor" do
      tool = instance_double(Smolagents::Tool)
      executor.send_tools(search: tool)
      executor.send_variables(query: "Ruby")

      expect(executor.tools["search"]).to eq(tool)
      expect(executor.variables["query"]).to eq("Ruby")
    end

    it "tools and variables are separate stores" do
      tool = instance_double(Smolagents::Tool)
      executor.send_tools(search: tool)
      executor.send_variables(search: "query string")

      expect(executor.tools["search"]).to eq(tool)
      expect(executor.variables["search"]).to eq("query string")
    end
  end

  describe "dangerous method detection" do
    it "blocks eval method" do
      tool = instance_double(Smolagents::Tool)

      expect do
        executor.send_tools(eval: tool)
      end.to raise_error(ArgumentError, /dangerous/)
    end

    it "blocks require method" do
      tool = instance_double(Smolagents::Tool)

      expect do
        executor.send_tools(require: tool)
      end.to raise_error(ArgumentError, /dangerous/)
    end

    it "allows non-dangerous method names" do
      tool = instance_double(Smolagents::Tool)
      safe_names = %w[search web fetch api query execute run do_something class]

      safe_names.each do |name|
        expect do
          executor.send_tools(name => tool)
        end.not_to raise_error
      end
    end
  end

  describe "error messages" do
    it "includes tool name in error" do
      tool = instance_double(Smolagents::Tool)

      expect do
        executor.send_tools(eval: tool)
      end.to raise_error(ArgumentError) { |e| e.message.include?("eval") }
    end

    it "clearly states the problem" do
      tool = instance_double(Smolagents::Tool)

      expect do
        executor.send_tools(eval: tool)
      end.to raise_error(ArgumentError) { |e| e.message.include?("dangerous") }
    end
  end

  describe "#initialize_tool_registration" do
    it "creates fresh hashes each time" do
      executor1 = test_executor.new
      executor2 = test_executor.new

      executor1.send_tools(search: instance_double(Smolagents::Tool))

      expect(executor1.tools.size).to eq(1)
      expect(executor2.tools.size).to eq(0)
    end

    it "is called during initialization" do
      executor = test_executor.new

      expect(executor.tools).to be_a(Hash)
      expect(executor.variables).to be_a(Hash)
    end
  end

  describe "attribute readers" do
    it "provides public tools accessor" do
      executor.send_tools(search: instance_double(Smolagents::Tool))

      expect(executor.tools).to be_a(Hash)
      expect(executor.tools["search"]).not_to be_nil
    end

    it "provides public variables accessor" do
      executor.send_variables(x: 42)

      expect(executor.variables).to be_a(Hash)
      expect(executor.variables["x"]).to eq(42)
    end

    it "attr_reader makes them accessible" do
      executor.send_tools(my_tool: instance_double(Smolagents::Tool))
      executor.send_variables(my_var: 100)

      # These should be accessible via public API
      expect { executor.tools }.not_to raise_error
      expect { executor.variables }.not_to raise_error
    end
  end

  describe "typical workflow" do
    it "registers tools and variables for execution" do
      search_tool = instance_double(Smolagents::Tool)
      calculate_tool = instance_double(Smolagents::Tool)

      executor.send_tools(
        search: search_tool,
        calculate: calculate_tool
      )

      executor.send_variables(
        query: "Ruby 3.0",
        max_results: 10,
        data: [1, 2, 3]
      )

      expect(executor.tools.size).to eq(2)
      expect(executor.variables.size).to eq(3)

      # Both are ready for code execution
      expect(executor.tools["search"]).to eq(search_tool)
      expect(executor.variables["query"]).to eq("Ruby 3.0")
    end
  end

  describe "edge cases" do
    it "handles empty tool registration" do
      executor.send_tools({})
      expect(executor.tools).to eq({})
    end

    it "handles empty variable registration" do
      executor.send_variables({})
      expect(executor.variables).to eq({})
    end

    # rubocop:disable Naming/VariableNumber -- testing tool names with numbers
    it "handles tools with underscores and numbers" do
      tool = instance_double(Smolagents::Tool)
      executor.send_tools(my_tool_123: tool)

      expect(executor.tools["my_tool_123"]).to eq(tool)
    end
    # rubocop:enable Naming/VariableNumber

    it "handles many tools" do
      tools_hash = {}
      100.times { |i| tools_hash["tool_#{i}"] = instance_double(Smolagents::Tool) }

      executor.send_tools(tools_hash)
      expect(executor.tools.size).to eq(100)
    end

    it "handles many variables" do
      vars_hash = {}
      100.times { |i| vars_hash["var_#{i}"] = i * 10 }

      executor.send_variables(vars_hash)
      expect(executor.variables.size).to eq(100)
    end
  end
end
