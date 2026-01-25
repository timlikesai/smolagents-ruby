module Smolagents
  module Tools
    class Tool
      # Class-level DSL methods for declaring tool metadata.
      #
      # Provides declarative attributes for name, description, inputs, and output
      # configuration. All values are frozen for Ractor shareability.
      module Dsl
        # Valid types for tool inputs and outputs (JSON Schema compatible).
        AUTHORIZED_TYPES = Set.new(%w[string boolean integer number image audio array object any null]).freeze

        # @!attribute [rw] tool_name
        #   Unique identifier for this tool.
        #   @return [String, nil]
        attr_reader :tool_name

        # @!attribute [rw] description
        #   Human-readable description for agent prompts.
        #   @return [String, nil]
        attr_reader :description

        # @!attribute [rw] output_type
        #   Return type (must be in AUTHORIZED_TYPES).
        #   @return [String] Defaults to "any"
        attr_reader :output_type

        # @!attribute [rw] output_schema
        #   Structured schema for complex output types.
        #   @return [Hash, nil]
        attr_reader :output_schema

        # @!attribute [r] inputs
        #   Input parameter specifications.
        #   @return [Hash{Symbol => Hash}]
        attr_reader :inputs

        def tool_name=(value)
          @tool_name = value&.to_s&.freeze
        end

        def description=(value)
          @description = value&.to_s&.freeze
        end

        def output_type=(value)
          @output_type = value&.to_s&.freeze
        end

        def output_schema=(value)
          @output_schema = Utilities::Transform.freeze(value)
        end

        def inputs=(value)
          normalized = Utilities::Transform.symbolize_keys(value)
          validate_inputs_schema!(normalized)
          @inputs = normalized
        end

        # Sets up default values for subclasses.
        def inherited(subclass)
          super
          subclass.instance_variable_set(:@tool_name, nil)
          subclass.instance_variable_set(:@description, nil)
          subclass.instance_variable_set(:@inputs, {}.freeze)
          subclass.instance_variable_set(:@output_type, "any")
          subclass.instance_variable_set(:@output_schema, nil)
        end

        private

        # Validates the inputs schema at definition time.
        #
        # @param inputs [Hash] The inputs hash to validate
        # @raise [ToolConfigurationError] if the schema is invalid
        def validate_inputs_schema!(inputs)
          return if inputs.nil? || inputs.empty?

          unless inputs.is_a?(Hash)
            raise ToolConfigurationError.new("inputs must be a Hash, got #{inputs.class}", config_key: :inputs)
          end

          inputs.each do |input_name, spec|
            validate_input_entry!(input_name, spec)
          end
        end

        # Validates a single input entry in the schema.
        #
        # @param input_name [Symbol] The name of the input
        # @param spec [Hash] The input specification
        # @raise [ToolConfigurationError] if the spec is invalid
        def validate_input_entry!(input_name, spec)
          unless spec.is_a?(Hash)
            raise ToolConfigurationError.new("Input '#{input_name}' must be a Hash, got #{spec.class}",
                                             config_key: :inputs)
          end

          unless spec.key?(:type)
            raise ToolConfigurationError.new("Input '#{input_name}' missing required key :type", config_key: :inputs)
          end

          unless spec.key?(:description)
            raise ToolConfigurationError.new("Input '#{input_name}' missing required key :description",
                                             config_key: :inputs)
          end

          validate_input_types!(input_name, spec[:type])
        end

        # Validates that input types are authorized.
        #
        # @param input_name [Symbol] The name of the input
        # @param types [String, Array<String>] The type or types to validate
        # @raise [ToolConfigurationError] if any type is invalid
        def validate_input_types!(input_name, types)
          Array(types).each do |type|
            next if AUTHORIZED_TYPES.include?(type.to_s)

            valid_types = AUTHORIZED_TYPES.to_a.sort.join(", ")
            raise ToolConfigurationError.new(
              "Input '#{input_name}' has invalid type '#{type}'. Valid types: #{valid_types}",
              config_key: :inputs
            )
          end
        end
      end
    end
  end
end
