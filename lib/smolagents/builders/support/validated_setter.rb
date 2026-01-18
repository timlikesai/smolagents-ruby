module Smolagents
  module Builders
    module Support
      # Generate validated setter methods with immutable builder pattern.
      #
      # Combines check_frozen!, validate!, and with_config into a single
      # declarative macro. Each generated method follows the pattern:
      # check_frozen! -> validate! -> with_config.
      #
      # @example Basic usage
      #   module MySetters
      #     extend Smolagents::Builders::Support::ValidatedSetter
      #
      #     validated_setter :max_steps, validate: Validators::POSITIVE_INTEGER
      #     validated_setter :temperature, validate: Validators.numeric_range(0.0, 2.0)
      #   end
      #
      # @example With custom key
      #   validated_setter :id, key: :model_id, validate: Validators::NON_EMPTY_STRING
      #
      # @example With transform
      #   validated_setter :imports, transform: :flatten, validate: Validators::ARRAY
      module ValidatedSetter
        # Generates a validated setter method.
        #
        # @param method_name [Symbol] Name of the setter method
        # @param key [Symbol] Config key (defaults to method_name)
        # @param validate [Proc, Symbol, nil] Validator lambda or symbol
        # @param transform [Symbol, Proc, nil] Value transformation
        # @return [void]
        def validated_setter(method_name, key: nil, validate: nil, transform: nil)
          config_key = key || method_name
          validator = resolve_validator(validate)
          transformer = resolve_transformer(transform)

          define_method(method_name) do |*args|
            check_frozen!
            value = args.length == 1 ? args.first : args
            value = transformer.call(value) if transformer
            validate!(method_name, value) if validator
            with_config(config_key => value)
          end
        end

        # Generates multiple validated setters from a hash.
        #
        # @param config [Hash] Setter definitions mapping method_name => options
        # @return [void]
        def validated_setters(config)
          config.each do |method_name, options|
            validated_setter(method_name, **options)
          end
        end

        VALIDATOR_MAP = {
          positive_integer: -> { Validators::POSITIVE_INTEGER },
          non_empty_string: -> { Validators::NON_EMPTY_STRING },
          boolean: -> { Validators::BOOLEAN },
          symbol: -> { Validators::SYMBOL },
          array: -> { Validators::ARRAY },
          hash: -> { Validators::HASH },
          numeric: -> { Validators::NUMERIC }
        }.freeze

        private

        def resolve_validator(validate)
          return validate if validate.is_a?(Proc)

          VALIDATOR_MAP[validate]&.call
        end

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
