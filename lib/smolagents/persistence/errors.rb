module Smolagents
  module Persistence
    class Error < AgentError; end

    class MissingModelError < Error
      attr_reader :expected_class

      def initialize(expected_class)
        @expected_class = expected_class
        super("Model required to load agent. Expected: #{expected_class}")
      end

      def deconstruct_keys(_keys) = { message:, expected_class: }
    end

    class UnknownToolError < Error
      attr_reader :tool_name, :available_tools

      def initialize(tool_name)
        @tool_name = tool_name
        @available_tools = Tools.names
        super("Tool '#{tool_name}' not in registry. Available: #{available_tools.join(", ")}")
      end

      def deconstruct_keys(_keys) = { message:, tool_name:, available_tools: }
    end

    class InvalidManifestError < Error
      attr_reader :validation_errors

      def initialize(errors)
        @validation_errors = Array(errors)
        super("Invalid manifest: #{validation_errors.join("; ")}")
      end

      def deconstruct_keys(_keys) = { message:, validation_errors: }
    end

    class VersionMismatchError < Error
      attr_reader :got_version, :expected_version

      def initialize(got, expected)
        @got_version = got
        @expected_version = expected
        super("Manifest version #{got} not supported. Expected: #{expected}")
      end

      def deconstruct_keys(_keys) = { message:, got_version:, expected_version: }
    end

    class UnserializableToolError < Error
      attr_reader :tool_name, :tool_class

      def initialize(tool_name, tool_class)
        @tool_name = tool_name
        @tool_class = tool_class
        super("Tool '#{tool_name}' (#{tool_class}) cannot be serialized. Only registry tools are supported.")
      end

      def deconstruct_keys(_keys) = { message:, tool_name:, tool_class: }
    end
  end
end
