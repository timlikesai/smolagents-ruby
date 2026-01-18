module Smolagents
  module Testing
    # Tool that records all calls for testing.
    #
    # SpyTool acts like a normal tool but records every invocation,
    # allowing you to assert on what was called and with what arguments.
    #
    # @example
    #   tool = SpyTool.new("search")
    #   tool.call(query: "Ruby")
    #   tool.call(query: "Python")
    #
    #   expect(tool.call_count).to eq(2)
    #   expect(tool.calls.map { |c| c[:query] }).to eq(["Ruby", "Python"])
    #
    # @see Helpers::ToolHelpers#spy_tool Convenience method for creating spy tools
    class SpyTool < Tools::Tool
      self.tool_name = "spy_tool"
      self.description = "Records all calls for testing"
      self.inputs = {}
      self.output_type = "string"

      # @!attribute [r] calls
      #   @return [Array<Hash>] All recorded calls with their arguments
      attr_reader :calls

      # Creates a new spy tool.
      #
      # @param name [String] Tool name (default: "spy_tool")
      # @param return_value [Object] Value to return from execute (default: "ok")
      def initialize(name = "spy_tool", return_value: "ok")
        super()
        self.class.tool_name = name
        @calls = []
        @return_value = return_value
      end

      # Executes the tool and records the call.
      #
      # @param kwargs [Hash] Arguments passed to the tool
      # @return [Object] The configured return_value
      def execute(**kwargs)
        @calls << kwargs
        @return_value
      end

      # Returns whether the tool was called at least once.
      #
      # @return [Boolean]
      def called? = @calls.any?

      # Returns the number of times the tool was called.
      #
      # @return [Integer]
      def call_count = @calls.size

      # Returns the arguments from the last call.
      #
      # @return [Hash, nil]
      def last_call = @calls.last

      # Clears all recorded calls.
      #
      # @return [void]
      def reset!
        @calls.clear
      end
    end
  end
end
