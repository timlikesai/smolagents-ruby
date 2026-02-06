module Smolagents
  module Builders
    module Support
      # Generate validated setter methods with immutable builder pattern.
      #
      # Combines check_frozen!, validate!, and with_config into a single
      # declarative macro. Each generated method follows the pattern:
      # check_frozen! -> validate!(from register_method) -> with_config.
      #
      # @example Basic usage
      #   module MySetters
      #     extend Smolagents::Builders::Support::ValidatedSetter
      #
      #     validated_setter :max_steps
      #     validated_setter :temperature
      #   end
      #
      # @example With custom config key
      #   validated_setter :id, key: :model_id
      #
      # @example With transform
      #   validated_setter :imports, transform: :flatten
      module ValidatedSetter
        # Generate a validated setter method with frozen check and auto-validation.
        #
        # Generates an immutable setter that checks frozen state, validates via
        # register_method validators, and returns a new builder.
        #
        # @param method_name [Symbol] Name of the setter method
        # @param key [Symbol] Config key (defaults to method_name)
        # @param transform [Symbol, Proc, nil] Value transformation
        # @return [void]
        def validated_setter(method_name, key: nil, transform: nil)
          config_key = key || method_name
          transformer = resolve_transformer(transform)

          define_method(method_name) do |*args|
            check_frozen!
            value = args.length == 1 ? args.first : args
            value = transformer.call(value) if transformer
            validate!(method_name, value)
            with_config(config_key => value)
          end
        end

        # Generate multiple validated setters from a hash configuration.
        #
        # @param config [Hash] Setter definitions mapping method_name => options
        # @return [void]
        def validated_setters(config)
          config.each do |method_name, options|
            validated_setter(method_name, **options)
          end
        end

        private

        # Resolve transformer to a callable proc.
        # @param transform [Symbol, Proc, nil] Transformer reference
        # @return [Proc, nil] Callable transformer or nil
        def resolve_transformer(transform)
          case transform
          when :flatten then ->(v) { Array(v).flatten }
          when :to_sym then lambda(&:to_sym)
          when :to_s then lambda(&:to_s)
          when Proc then transform
          end
        end
      end
    end
  end
end
