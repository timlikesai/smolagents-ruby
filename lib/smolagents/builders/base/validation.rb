module Smolagents
  module Builders
    module Base
      # Validation logic for builder configuration.
      #
      # Provides methods for validating builder method arguments and ensuring
      # required configuration is present before building. Works with metadata
      # registered via {Metadata#register_method}.
      #
      # @example Using validation in a builder method
      #   def max_steps(n)
      #     check_frozen!
      #     validate!(:max_steps, n)
      #     with_config(max_steps: n)
      #   end
      #
      # @see Metadata#register_method Define validation rules
      module Validation
        # Validate a value against registered validation rules.
        #
        # Looks up the validation block for the given method name and runs the
        # validator against the value. Raises ArgumentError with a helpful message
        # if validation fails. Does nothing if no validator is registered.
        #
        # @param method_name [Symbol] Method being called (must be registered with register_method)
        # @param value [Object] Value to validate
        #
        # @return [void]
        #
        # @raise [ArgumentError] If validation block returns false, includes method description
        #
        # @example Validating within a builder method
        #   def max_steps(n)
        #     check_frozen!
        #     validate!(:max_steps, n)  # Raises ArgumentError if invalid
        #     with_config(max_steps: n)
        #   end
        #
        # @see #validate_required! Validate all required methods are called
        def validate!(method_name, value)
          return unless self.class.registered_methods[method_name]

          validator = self.class.registered_methods[method_name][:validates]
          return unless validator

          return if validator.call(value)

          description = self.class.registered_methods[method_name][:description]
          raise ArgumentError, "Invalid value for #{method_name}: #{value.inspect}. #{description}"
        end

        # Validate that all required methods have been called.
        #
        # Checks that every method registered with register_method(required: true)
        # has been set in the configuration. Useful to call before {#build} to ensure
        # all mandatory configuration is present.
        #
        # @return [void]
        #
        # @raise [ArgumentError] If required methods are missing, lists missing methods
        #
        # @example Validating before building
        #   def build
        #     validate_required!  # Raises if model is missing
        #     # ... build agent ...
        #   end
        #
        # @see Metadata#register_method Mark methods as required
        def validate_required!
          missing = self.class.required_methods.reject { |method| configuration.key?(method) }
          return if missing.empty?

          raise ArgumentError, "Missing required configuration: #{missing.join(", ")}. Use .help for details."
        end
      end
    end
  end
end
