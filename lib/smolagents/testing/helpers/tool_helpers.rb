module Smolagents
  module Testing
    module Helpers
      # Tool-related test helper methods.
      #
      # Provides convenience methods for creating mock and spy tools
      # for testing agent tool interactions.
      #
      # @example Creating a spy tool
      #   tool = spy_tool("search")
      #   agent.run("search for Ruby")
      #   expect(tool).to be_called
      #   expect(tool.last_call[:query]).to eq("Ruby")
      #
      # @example Creating a mock tool
      #   tool = mock_tool("calculator", returns: 42)
      module ToolHelpers
        # Creates a spy tool for tracking tool invocations.
        #
        # @param name [String] Tool name
        # @param return_value [Object] Value to return from execute (default: "ok")
        # @return [SpyTool] A spy tool instance
        def spy_tool(name, return_value: "ok")
          SpyTool.new(name, return_value:)
        end

        # Creates a mock tool with predetermined behavior.
        #
        # @param name [String] Tool name
        # @param returns [Object] Value to return from execute
        # @param raises [Exception, nil] Exception to raise when called
        # @return [Tool] A mock tool instance
        #
        # @example Returning a value
        #   tool = mock_tool("calculator", returns: 42)
        #
        # @example Raising an error
        #   tool = mock_tool("failing", raises: RuntimeError.new("oops"))
        def mock_tool(name, returns: nil, raises: nil)
          MockToolBuilder.build(name, returns:, raises:)
        end
      end

      # Builds mock tool classes dynamically.
      #
      # @api private
      module MockToolBuilder
        module_function

        # Builds a mock tool with the given configuration.
        #
        # @param name [String] Tool name
        # @param returns [Object] Value to return
        # @param raises [Exception, nil] Exception to raise
        # @return [Tool] Mock tool instance
        def build(name, returns:, raises:)
          klass = Class.new(Tools::Tool) do
            self.tool_name = name
            self.description = "Mock #{name} tool"
            self.inputs = { "input" => { "type" => "string", "description" => "Input" } }
            self.output_type = "string"
          end
          define_execute(klass, returns, raises)
          klass.new
        end

        # @!visibility private
        def define_execute(klass, returns, raises)
          klass.define_method(:execute) do |**_|
            raise raises if raises

            returns
          end
        end
      end
    end
  end
end
