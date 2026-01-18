module Smolagents
  module Tools
    class Tool
      # Input and configuration validation for tools.
      #
      # Provides validation at two levels:
      # - Configuration validation (tool definition correctness)
      # - Runtime validation (tool invocation arguments)
      module Validation
        # Validates tool configuration on instantiation.
        #
        # @raise [ArgumentError] if configuration is invalid
        def validate_arguments!
          validate_required_attributes!
          validate_output_type!
          inputs.each { |input_name, spec| validate_input_spec!(input_name, spec) }
        end

        # Validates runtime tool arguments from agents.
        #
        # @param arguments [Hash] Arguments to validate
        # @raise [AgentToolCallError] if arguments are invalid
        def validate_tool_arguments(arguments)
          validate_arguments_type(arguments)
          validate_required_inputs(arguments)
          validate_no_extra_keys(arguments)
        end

        # Validates and sanitizes arguments using security validation.
        #
        # @param arguments [Hash] Arguments to validate
        # @return [Hash] Sanitized arguments
        # @raise [ArgumentValidationError] if validation fails
        def validate_and_sanitize_arguments(arguments)
          Security::ArgumentValidator.validate_all!(arguments, inputs, tool_name: name)
        end

        # Whether security validation is enabled for this tool.
        # Override to return false to disable validation.
        #
        # @return [Boolean]
        def security_validation_enabled? = true

        private

        def validate_required_attributes!
          raise ArgumentError, "Tool must have a name" unless name
          raise ArgumentError, "Tool must have a description" unless description
          raise ArgumentError, "Tool inputs must be a Hash" unless inputs.is_a?(Hash)
          raise ArgumentError, "Tool must have an output_type" unless output_type
        end

        def validate_output_type!
          return if Dsl::AUTHORIZED_TYPES.include?(output_type)

          raise ArgumentError, "Invalid output_type: #{output_type}"
        end

        def validate_input_spec!(input_name, spec)
          raise ArgumentError, "Input '#{input_name}' must be a Hash" unless spec.is_a?(Hash)
          raise ArgumentError, "Input '#{input_name}' must have type" unless spec.key?(:type)
          raise ArgumentError, "Input '#{input_name}' must have description" unless spec.key?(:description)

          Array(spec[:type]).each do |type|
            unless Dsl::AUTHORIZED_TYPES.include?(type)
              raise ArgumentError, "Invalid type '#{type}' for input '#{input_name}'"
            end
          end
        end

        def validate_arguments_type(arguments)
          return if arguments.is_a?(Hash)

          raise AgentToolCallError, "Tool '#{name}' expects Hash arguments, got #{arguments.class}"
        end

        def validate_required_inputs(arguments)
          inputs.each do |input_name, spec|
            next if spec[:nullable]
            # Check both string and symbol keys since JSON parsing yields string keys
            next if arguments.key?(input_name) || arguments.key?(input_name.to_s) || arguments.key?(input_name.to_sym)

            raise AgentToolCallError, "Tool '#{name}' missing required input: #{input_name}"
          end
        end

        def validate_no_extra_keys(arguments)
          # Accept both string and symbol keys
          valid_keys = inputs.keys.flat_map { [it, it.to_s, it.to_sym] }
          arguments.each_key do |key|
            next if valid_keys.include?(key)

            raise AgentToolCallError, "Tool '#{name}' received unexpected input: #{key}"
          end
        end
      end
    end
  end
end
