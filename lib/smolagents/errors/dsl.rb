# Metaprogramming DSL for declarative error class generation.
module Smolagents
  module Errors
    # Configuration for error class generation.
    ErrorConfig = Data.define(:parent, :fields, :defaults, :default_message, :predicates) do
      def self.from(parent: :AgentError, fields: [], defaults: {}, default_message: nil, predicates: {})
        new(parent:, fields:, defaults:, default_message:, predicates:)
      end
    end

    # DSL for generating error classes with pattern matching support.
    module DSL
      def define_error(name, **)
        config = ErrorConfig.from(**)
        parent_class = resolve_parent(config.parent)
        parent_fields = parent_class.respond_to?(:error_fields) ? parent_class.error_fields : []
        const_set(name, ErrorClassBuilder.new(parent_class, parent_fields, config).build)
      end

      private

      def resolve_parent(parent) = parent.is_a?(Symbol) ? const_get(parent) : parent
    end

    # Builds error classes with fields, defaults, and predicates.
    class ErrorClassBuilder
      def initialize(parent_class, parent_fields, config)
        @parent_class = parent_class
        @parent_fields = parent_fields
        @config = config
      end

      def build
        klass = Class.new(@parent_class)
        setup_class_methods(klass)
        setup_instance_methods(klass)
        setup_predicates(klass)
        klass
      end

      private

      def setup_class_methods(klass)
        fields = @config.fields
        klass.define_singleton_method(:error_fields) { fields }
        klass.attr_reader(*fields) unless fields.empty?
      end

      def setup_instance_methods(klass)
        define_initialize(klass)
        define_deconstruct_keys(klass)
      end

      def define_initialize(klass)
        fields, defaults, parent_fields, default_message = extract_init_context
        klass.define_method(:initialize) do |message = nil, **kwargs|
          fields.each { |field| instance_variable_set(:"@#{field}", kwargs.fetch(field, defaults[field])) }
          parent_kwargs = defaults.slice(*parent_fields).merge(kwargs.except(*fields))
          super(message || default_message&.call(kwargs), **parent_kwargs)
        end
      end

      def extract_init_context = [@config.fields, @config.defaults, @parent_fields, @config.default_message]

      def define_deconstruct_keys(klass)
        fields = @config.fields
        klass.define_method(:deconstruct_keys) do |_keys|
          fields.each_with_object(super({})) { |f, h| h[f] = send(f) }
        end
      end

      def setup_predicates(klass)
        @config.predicates.each { |name, value| define_predicate(klass, name, value) }
      end

      def define_predicate(klass, method_name, expected_value)
        if field_reference?(expected_value)
          define_field_predicate(klass, method_name, expected_value)
        else
          define_value_predicate(klass, method_name, expected_value)
        end
      end

      def field_reference?(value) = value.is_a?(Symbol) && @config.fields.include?(value)

      def define_field_predicate(klass, method_name, field)
        klass.define_method(:"#{method_name}?") { !!send(field) }
      end

      def define_value_predicate(klass, method_name, expected)
        klass.define_method(:"#{method_name}?") { send(method_name) == expected }
      end
    end
  end
end
