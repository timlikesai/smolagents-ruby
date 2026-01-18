module Smolagents
  module Builders
    module Support
      # Generate simple setter methods from hash configuration.
      #
      # Reduces repetitive setter method definitions by generating them from
      # a declarative hash. Supports value transformation, validation, and
      # both mutable (@config) and immutable (with_config) patterns.
      #
      # @example Basic usage with mutable config
      #   module MySetters
      #     extend Smolagents::Builders::Support::SetterFactory
      #
      #     define_setters(
      #       task: { key: :task },
      #       max_steps: { key: :max_steps },
      #       tools: { key: :tools, transform: :flatten }
      #     )
      #   end
      #
      # @example With validation (immutable pattern)
      #   module MySetters
      #     extend Smolagents::Builders::Support::SetterFactory
      #
      #     define_setters(
      #       max_steps: { key: :max_steps, validate: Validators::POSITIVE_INTEGER },
      #       temperature: { key: :temperature, validate: Validators.numeric_range(0.0, 2.0) }
      #     ), immutable: true
      #   end
      module SetterFactory
        # Generates setter methods from a configuration hash.
        #
        # @param config [Hash] Setter definitions mapping method_name => options
        # @option config [Symbol] :key Config key to set (required)
        # @option config [Symbol, Proc, nil] :transform Value transformation
        # @option config [Proc, nil] :validate Validation lambda
        # @param immutable [Boolean] Use with_config (true) or @config (false)
        # @return [void]
        def define_setters(config = nil, immutable: false, **kwargs)
          # Support both define_setters({ hash }) and define_setters(name: {...})
          config = kwargs if config.nil? && kwargs.any?
          config.each do |method_name, options|
            define_setter(method_name, options, immutable:)
          end
        end

        private

        def define_setter(method_name, options, immutable:)
          key = options[:key]
          transform = resolve_transform(options[:transform])
          validate = options[:validate]

          if immutable
            define_immutable_setter(method_name, key, transform, validate)
          else
            define_mutable_setter(method_name, key, transform)
          end
        end

        def define_immutable_setter(method_name, key, transform, validate)
          define_method(method_name) do |*args|
            value = args.length == 1 ? args.first : args
            value = transform.call(value) if transform
            validate!(method_name, value) if validate && respond_to?(:validate!, true)
            with_config(key => value)
          end
        end

        def define_mutable_setter(method_name, key, transform)
          define_method(method_name) do |*args|
            value = args.length == 1 ? args.first : args
            value = transform.call(value) if transform
            @config[key] = value
            self
          end
        end

        def resolve_transform(transform)
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
