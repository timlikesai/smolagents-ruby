module Smolagents
  module Testing
    # Tool definitions used by capability tests - created once and reused.
    module TestTools
      module_function

      def echo = @echo ||= build_echo
      def add = @add ||= build_add
      def multiply = @multiply ||= build_multiply
      def data = @data ||= build_data
      def failing = @failing ||= build_failing
      def strict_add = @strict_add ||= build_strict_add

      def build_echo
        Tools.create("echo", description: "Echoes back the message",
                             inputs: { message: { type: "string", description: "Message to echo" } },
                             output_type: "string") { |message:| message }
      end

      def build_add
        Tools.create("add", description: "Adds two numbers",
                            inputs: { a: { type: "integer", description: "First number" },
                                      b: { type: "integer", description: "Second number" } },
                            output_type: "integer") { |a:, b:| a + b }
      end

      def build_multiply
        Tools.create("multiply", description: "Multiplies two numbers",
                                 inputs: { a: { type: "integer", description: "First number" },
                                           b: { type: "integer", description: "Second number" } },
                                 output_type: "integer") { |a:, b:| a * b }
      end

      def build_data
        Tools.create("get_data", description: "Returns structured data with name, count, and active fields",
                                 inputs: {}, output_type: "object") do
          { name: "TestItem", count: 42,
            active: true }
        end
      end

      def build_failing
        Tools.create("failing_tool", description: "A tool that always fails (for testing error handling)",
                                     inputs: {}, output_type: "string") do
          raise StandardError,
                "Tool intentionally failed"
        end
      end

      def build_strict_add
        Tools.create("strict_add", description: "Adds two numbers (integers only, fails on strings)",
                                   inputs: { a: { type: "integer", description: "First number (must be integer)" },
                                             b: { type: "integer",
                                                  description: "Second number (must be integer)" } },
                                   output_type: "integer") { |a:, b:| validate_and_add(a, b) }
      end

      def validate_and_add(val_a, val_b)
        raise ArgumentError, "Both arguments must be integers" unless val_a.is_a?(Integer) && val_b.is_a?(Integer)

        val_a + val_b
      end
    end
  end
end
