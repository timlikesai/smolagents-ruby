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
          @output_schema = deep_freeze(value)
        end

        def inputs=(value)
          @inputs = deep_symbolize_keys(value)
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

        def deep_symbolize_keys(hash)
          return hash unless hash.is_a?(Hash)

          hash.transform_keys(&:to_sym).transform_values do |value|
            value.is_a?(Hash) ? deep_symbolize_keys(value) : value
          end
        end
      end
    end
  end
end
