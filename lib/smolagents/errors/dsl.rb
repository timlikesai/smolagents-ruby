# Metaprogramming DSL for declarative error class generation.
module Smolagents
  module Errors
    # DSL for generating error classes with pattern matching support.
    module DSL
      def define_error(name, parent: :AgentError, fields: [], defaults: {}, default_message: nil, predicates: {})
        parent_class = resolve_parent(parent)
        parent_fields = parent_class.respond_to?(:error_fields) ? parent_class.error_fields : []

        const_set(name, build_error_class(parent_class, fields, parent_fields, defaults, default_message, predicates))
      end

      private

      def resolve_parent(parent) = parent.is_a?(Symbol) ? const_get(parent) : parent

      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      def build_error_class(parent_class, fields, parent_fields, defaults, default_message, predicates)
        Class.new(parent_class) do
          define_singleton_method(:error_fields) { fields }
          attr_reader(*fields) unless fields.empty?

          define_method(:initialize) do |message = nil, **kwargs|
            fields.each { |field| instance_variable_set(:"@#{field}", kwargs.fetch(field, defaults[field])) }
            parent_kwargs = defaults.slice(*parent_fields).merge(kwargs.slice(*parent_fields))
            super(message || default_message&.call(kwargs), **parent_kwargs)
          end

          define_method(:deconstruct_keys) do |_keys|
            fields.each_with_object(super({})) { |f, h| h[f] = send(f) }
          end

          # Generate predicate methods
          predicates.each do |method_name, expected_value|
            if expected_value.is_a?(Symbol) && fields.include?(expected_value)
              # Symbol matching field name: check truthiness of that field
              define_method(:"#{method_name}?") { !!send(expected_value) }
            else
              # Literal value: check if field equals expected value
              define_method(:"#{method_name}?") { send(method_name) == expected_value }
            end
          end
        end
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
    end
  end
end
