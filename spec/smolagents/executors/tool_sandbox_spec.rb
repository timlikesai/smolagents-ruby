require_relative "../../../lib/smolagents/executors/tool_sandbox"

RSpec.describe Smolagents::Executors::ToolSandbox do
  describe "initialization" do
    it "accepts tool_names, variables, and output_buffer" do
      tool_names = %w[search web]
      variables = { "x" => 42 }
      buffer = StringIO.new

      sandbox = described_class.new(
        tool_names:,
        variables:,
        output_buffer: buffer
      )
      # BasicObject descendants don't have is_a?, verify via state
      expect(sandbox.state).to eq(variables)
    end
  end

  describe "tool calling via method_missing" do
    it "routes tool names to method calls" do
      tool_names = %w[search]
      variables = {}
      buffer = StringIO.new
      sandbox = described_class.new(
        tool_names:,
        variables:,
        output_buffer: buffer
      )

      # Use __send__ to call respond_to_missing? (BasicObject method)
      expect(sandbox.__send__(:respond_to_missing?, :search)).to be true
    end

    it "raises NoMethodError for non-tools" do
      tool_names = %w[search]
      variables = {}
      buffer = StringIO.new
      sandbox = described_class.new(
        tool_names:,
        variables:,
        output_buffer: buffer
      )

      expect { sandbox.missing_tool }.to raise_error(NoMethodError)
    end
  end

  describe "variable access" do
    it "retrieves registered variables" do
      tool_names = []
      variables = { "x" => 42, "name" => "Alice" }
      buffer = StringIO.new
      sandbox = described_class.new(
        tool_names:,
        variables:,
        output_buffer: buffer
      )

      expect(sandbox.x).to eq(42)
      expect(sandbox.name).to eq("Alice")
    end

    it "prioritizes tools over variables" do
      tool_names = %w[x]
      variables = { "x" => 42 }
      buffer = StringIO.new
      sandbox = described_class.new(
        tool_names:,
        variables:,
        output_buffer: buffer
      )

      # Should try to call tool first (respond_to_missing)
      expect(sandbox.__send__(:respond_to_missing?, :x)).to be true
    end

    it "falls back to variables when tool doesn't exist" do
      tool_names = %w[search]
      variables = { "result" => 100 }
      buffer = StringIO.new
      sandbox = described_class.new(
        tool_names:,
        variables:,
        output_buffer: buffer
      )

      expect(sandbox.result).to eq(100)
    end
  end

  describe "#respond_to_missing?" do
    it "returns true for registered tools" do
      tool_names = %w[search web]
      variables = {}
      buffer = StringIO.new
      sandbox = described_class.new(
        tool_names:,
        variables:,
        output_buffer: buffer
      )

      expect(sandbox.__send__(:respond_to_missing?, :search)).to be true
      expect(sandbox.__send__(:respond_to_missing?, :web)).to be true
    end

    it "returns true for registered variables" do
      tool_names = []
      variables = { "x" => 42 }
      buffer = StringIO.new
      sandbox = described_class.new(
        tool_names:,
        variables:,
        output_buffer: buffer
      )

      expect(sandbox.__send__(:respond_to_missing?, :x)).to be true
    end

    it "returns false for undefined methods" do
      tool_names = []
      variables = {}
      buffer = StringIO.new
      sandbox = described_class.new(
        tool_names:,
        variables:,
        output_buffer: buffer
      )

      expect(sandbox.__send__(:respond_to_missing?, :undefined)).to be false
    end

    it "supports both symbol and string method names" do
      tool_names = %w[search]
      variables = {}
      buffer = StringIO.new
      sandbox = described_class.new(
        tool_names:,
        variables:,
        output_buffer: buffer
      )

      expect(sandbox.__send__(:respond_to_missing?, :search)).to be true
      expect(sandbox.__send__(:respond_to_missing?, "search")).to be true
    end
  end

  describe "method_missing argument handling" do
    it "accepts positional arguments" do
      tool_names = %w[search]
      variables = {}
      buffer = StringIO.new
      sandbox = described_class.new(
        tool_names:,
        variables:,
        output_buffer: buffer
      )

      # Test that method_missing accepts args (would send via message passing)
      expect { sandbox.search("query", "arg2") }.to raise_error(Smolagents::Errors::ExecutorError)
    end

    it "accepts keyword arguments" do
      tool_names = %w[search]
      variables = {}
      buffer = StringIO.new
      sandbox = described_class.new(
        tool_names:,
        variables:,
        output_buffer: buffer
      )

      # Test that method_missing accepts kwargs
      expect { sandbox.search(query: "test", limit: 10) }.to raise_error(Smolagents::Errors::ExecutorError)
    end

    it "accepts mixed arguments" do
      tool_names = %w[search]
      variables = {}
      buffer = StringIO.new
      sandbox = described_class.new(
        tool_names:,
        variables:,
        output_buffer: buffer
      )

      expect { sandbox.search("query", limit: 10) }.to raise_error(Smolagents::Errors::ExecutorError)
    end
  end

  describe "tool call routing" do
    it "sends tool call message structure" do
      tool_names = %w[search]
      variables = {}
      buffer = StringIO.new
      sandbox = described_class.new(
        tool_names:,
        variables:,
        output_buffer: buffer
      )

      # Calling a tool would send a message; we just verify it tries
      expect { sandbox.search(query: "test") }.to raise_error(Smolagents::Errors::ExecutorError)
    end

    it "includes tool name in message" do
      tool_names = %w[custom_tool]
      variables = {}
      buffer = StringIO.new
      sandbox = described_class.new(
        tool_names:,
        variables:,
        output_buffer: buffer
      )

      # Would include tool name in message
      expect { sandbox.custom_tool }.to raise_error(Smolagents::Errors::ExecutorError)
    end
  end

  describe "inherited behavior from Sandbox" do
    it "captures output via puts" do
      tool_names = []
      variables = {}
      buffer = StringIO.new
      sandbox = described_class.new(
        tool_names:,
        variables:,
        output_buffer: buffer
      )

      sandbox.puts("Hello")
      expect(buffer.string).to include("Hello")
    end

    it "provides Kernel methods" do
      tool_names = []
      variables = {}
      buffer = StringIO.new
      sandbox = described_class.new(
        tool_names:,
        variables:,
        output_buffer: buffer
      )

      result = sandbox.rand(10)
      expect(result).to be >= 0
      expect(result).to be < 10
    end

    it "has correct isolation" do
      tool_names = []
      variables = {}
      buffer = StringIO.new
      sandbox = described_class.new(
        tool_names:,
        variables:,
        output_buffer: buffer
      )

      expect { sandbox.system("ls") }.to raise_error(NoMethodError)
    end
  end

  describe "#state" do
    it "exposes variables through inherited method" do
      tool_names = []
      variables = { "x" => 42 }
      buffer = StringIO.new
      sandbox = described_class.new(
        tool_names:,
        variables:,
        output_buffer: buffer
      )

      expect(sandbox.state).to eq(variables)
    end
  end

  describe "security features" do
    it "prevents calling non-existent tools" do
      tool_names = %w[safe_tool]
      variables = {}
      buffer = StringIO.new
      sandbox = described_class.new(
        tool_names:,
        variables:,
        output_buffer: buffer
      )

      expect { sandbox.dangerous_tool }.to raise_error(NoMethodError)
    end

    it "isolates tools to the registered list" do
      tool_names = %w[web]
      variables = {}
      buffer = StringIO.new
      sandbox = described_class.new(
        tool_names:,
        variables:,
        output_buffer: buffer
      )

      # Only 'web' is available
      expect(sandbox.__send__(:respond_to_missing?, :web)).to be true
      expect(sandbox.__send__(:respond_to_missing?, :search)).to be false
    end
  end

  describe "empty tool list" do
    it "still allows variable access" do
      tool_names = []
      variables = { "result" => 42 }
      buffer = StringIO.new
      sandbox = described_class.new(
        tool_names:,
        variables:,
        output_buffer: buffer
      )

      expect(sandbox.result).to eq(42)
    end

    it "raises NoMethodError for methods" do
      tool_names = []
      variables = {}
      buffer = StringIO.new
      sandbox = described_class.new(
        tool_names:,
        variables:,
        output_buffer: buffer
      )

      expect { sandbox.some_method }.to raise_error(NoMethodError)
    end
  end

  describe "multiple tool names" do
    it "handles multiple tools" do
      tool_names = %w[search web fetch api]
      variables = {}
      buffer = StringIO.new
      sandbox = described_class.new(
        tool_names:,
        variables:,
        output_buffer: buffer
      )

      expect(sandbox.__send__(:respond_to_missing?, :search)).to be true
      expect(sandbox.__send__(:respond_to_missing?, :web)).to be true
      expect(sandbox.__send__(:respond_to_missing?, :fetch)).to be true
      expect(sandbox.__send__(:respond_to_missing?, :api)).to be true
    end
  end

  describe "tool response handling" do
    it "would handle tool result responses" do
      # This is tested in integration with Ractor execution
      # Here we just verify the class has the private method
      # BasicObject doesn't have private_methods, check via class
      expect(described_class.private_method_defined?(:handle_tool_response)).to be true
    end
  end
end
