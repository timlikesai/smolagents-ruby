module Smolagents
  module Persistence
    # Base error class for all persistence-related errors.
    # Inherits from {Errors::AgentError} to maintain the error hierarchy.
    # @see Errors::AgentError
    class Error < Errors::AgentError; end

    # Raised when attempting to load an agent without providing a model.
    #
    # Models are never serialized for security (API keys), so they must
    # be provided when loading saved agents.
    #
    # @example Handling missing model
    #   begin
    #     Agent.from_folder("./my_agent")
    #   rescue MissingModelError => e
    #     puts "Need to provide: #{e.expected_class}"
    #   end
    class MissingModelError < Error
      attr_reader :expected_class

      def initialize(expected_class)
        @expected_class = expected_class
        super("Model required to load agent. Expected: #{expected_class}")
      end

      def deconstruct_keys(_keys) = { message:, expected_class: }
    end

    # Raised when a tool referenced in a manifest is not in the registry.
    #
    # Only tools registered in Tools::REGISTRY can be serialized and loaded.
    # Custom tools must be registered before saving or loading agents.
    #
    # @example Handling unknown tool
    #   begin
    #     Agent.from_folder("./agent_with_custom_tool", model:)
    #   rescue UnknownToolError => e
    #     puts "Available: #{e.available_tools.join(', ')}"
    #   end
    class UnknownToolError < Error
      attr_reader :tool_name, :available_tools

      def initialize(tool_name)
        @tool_name = tool_name
        @available_tools = Tools.names
        super("Tool '#{tool_name}' not in registry. Available: #{available_tools.join(", ")}")
      end

      def deconstruct_keys(_keys) = { message:, tool_name:, available_tools: }
    end

    # Raised when a manifest file is malformed or missing required fields.
    #
    # @example Handling validation errors
    #   begin
    #     AgentManifest.from_h(incomplete_data)
    #   rescue InvalidManifestError => e
    #     e.validation_errors.each { |err| puts "- #{err}" }
    #   end
    class InvalidManifestError < Error
      attr_reader :validation_errors

      def initialize(errors)
        @validation_errors = Array(errors)
        super("Invalid manifest: #{validation_errors.join("; ")}")
      end

      def deconstruct_keys(_keys) = { message:, validation_errors: }
    end

    # Raised when a manifest's version is incompatible with the current code.
    #
    # Manifest versions allow for schema evolution. When the version doesn't
    # match, the manifest cannot be safely loaded.
    class VersionMismatchError < Error
      attr_reader :got_version, :expected_version

      def initialize(got, expected)
        @got_version = got
        @expected_version = expected
        super("Manifest version #{got} not supported. Expected: #{expected}")
      end

      def deconstruct_keys(_keys) = { message:, got_version:, expected_version: }
    end

    # Raised when attempting to serialize a tool not in the registry.
    #
    # For security, only tools in Tools::REGISTRY can be serialized.
    # This prevents arbitrary code execution when loading manifests.
    class UnserializableToolError < Error
      attr_reader :tool_name, :tool_class

      def initialize(tool_name, tool_class)
        @tool_name = tool_name
        @tool_class = tool_class
        super("Tool '#{tool_name}' (#{tool_class}) cannot be serialized. Only registry tools are supported.")
      end

      def deconstruct_keys(_keys) = { message:, tool_name:, tool_class: }
    end

    # Raised when a manifest references a class not in the allowlist.
    #
    # For security, only certain agent and model classes can be instantiated
    # from manifests. This prevents arbitrary code execution.
    #
    # @see ALLOWED_AGENT_CLASSES
    # @see ALLOWED_MODEL_CLASSES
    class UntrustedClassError < Error
      attr_reader :class_name, :allowed_classes

      def initialize(class_name, allowed_classes)
        @class_name = class_name
        @allowed_classes = allowed_classes
        super("Class '#{class_name}' is not in the allowlist. Allowed: #{allowed_classes.join(", ")}")
      end

      def deconstruct_keys(_keys) = { message:, class_name:, allowed_classes: }
    end
  end
end
