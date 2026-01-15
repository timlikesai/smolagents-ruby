# Metaprogramming DSL for declarative error class generation.
module Smolagents
  module Errors
    # DSL for generating error classes with pattern matching support.
    module DSL
      def define_error(name, parent: :AgentError, attrs: [], defaults: {}, default_message: nil)
        parent_class = resolve_parent(parent)
        parent_attrs = parent_class.respond_to?(:error_attrs) ? parent_class.error_attrs : []

        const_set(name, build_error_class(parent_class, attrs, parent_attrs, defaults, default_message))
      end

      private

      def resolve_parent(parent) = parent.is_a?(Symbol) ? const_get(parent) : parent

      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      def build_error_class(parent_class, attrs, parent_attrs, defaults, default_message)
        Class.new(parent_class) do
          define_singleton_method(:error_attrs) { attrs }
          attr_reader(*attrs) unless attrs.empty?

          define_method(:initialize) do |message = nil, **kwargs|
            attrs.each { |attr| instance_variable_set(:"@#{attr}", kwargs.fetch(attr, defaults[attr])) }
            parent_kwargs = defaults.slice(*parent_attrs).merge(kwargs.slice(*parent_attrs))
            super(message || default_message&.call(kwargs), **parent_kwargs)
          end

          define_method(:deconstruct_keys) do |_keys|
            attrs.each_with_object(super({})) { |a, h| h[a] = send(a) }
          end
        end
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
    end
  end
end
