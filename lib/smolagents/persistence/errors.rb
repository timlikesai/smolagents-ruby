# Persistence error classes with pattern matching support.
# Uses DSL pattern from Errors::DSL for declarative error generation.
module Smolagents
  module Persistence
    # Base error class for all persistence-related errors.
    # Inherits from {Errors::AgentError} to maintain the error hierarchy.
    class Error < Errors::AgentError
      def self.error_fields = []
    end

    # DSL for persistence-specific error generation.
    module ErrorDSL
      def define_persistence_error(name, fields:, message_template: nil, computed: {})
        klass = Class.new(Error)
        setup_fields(klass, fields)
        setup_initialize(klass, fields, computed, message_template)
        setup_deconstruct(klass, fields + computed.keys)
        const_set(name, klass)
      end

      private

      def setup_fields(klass, fields)
        klass.define_singleton_method(:error_fields) { fields }
        klass.attr_reader(*fields)
      end

      def setup_initialize(klass, fields, computed, message_template)
        klass.define_method(:initialize) do |*args|
          fields.each_with_index { |f, i| instance_variable_set(:"@#{f}", args[i]) }
          computed.each { |name, block| instance_variable_set(:"@#{name}", instance_exec(&block)) }
          klass.attr_reader(*computed.keys) unless computed.empty?
          super(instance_exec(&message_template))
        end
      end

      def setup_deconstruct(klass, all_fields)
        klass.define_method(:deconstruct_keys) do |_keys|
          all_fields.each_with_object({ message: }) { |f, h| h[f] = instance_variable_get(:"@#{f}") }
        end
      end
    end

    extend ErrorDSL

    # Error definitions using DSL
    define_persistence_error :MissingModelError,
                             fields: [:expected_class],
                             message_template: -> { "Model required to load agent. Expected: #{@expected_class}" }

    define_persistence_error :UnknownToolError,
                             fields: [:tool_name],
                             computed: { available_tools: -> { Tools.names } },
                             message_template: lambda {
                               "Tool '#{@tool_name}' not in registry. Available: #{@available_tools.join(", ")}"
                             }

    define_persistence_error :InvalidManifestError,
                             fields: [:validation_errors],
                             message_template: -> { "Invalid manifest: #{@validation_errors.join("; ")}" }

    # Override initialize to handle Array coercion
    InvalidManifestError.prepend(Module.new do
      def initialize(errors)
        super(Array(errors))
      end
    end)

    define_persistence_error :VersionMismatchError,
                             fields: %i[got_version expected_version],
                             message_template: lambda {
                               "Manifest version #{@got_version} not supported. Expected: #{@expected_version}"
                             }

    define_persistence_error :UnserializableToolError,
                             fields: %i[tool_name tool_class],
                             message_template: lambda {
                               "Tool '#{@tool_name}' (#{@tool_class}) cannot be serialized. " \
                                 "Only registry tools are supported."
                             }

    define_persistence_error :UntrustedClassError,
                             fields: %i[class_name allowed_classes],
                             message_template: lambda {
                               "Class '#{@class_name}' is not in the allowlist. " \
                                 "Allowed: #{@allowed_classes.join(", ")}"
                             }
  end
end
