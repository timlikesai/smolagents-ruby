module Smolagents
  module Security
    # Immutable rule for validating tool arguments.
    #
    # @example Creating a string rule
    #   rule = ValidationRule.for_string(max_length: 100)
    #   rule.type  #=> "string"
    #
    # @example Creating from a tool spec
    #   spec = { type: "string", description: "Query", nullable: true }
    #   rule = ValidationRule.from_spec(spec)
    #   rule.required  #=> false
    ValidationRule = Data.define(:type, :max_length, :pattern, :required, :sanitize, :detect_dangerous) do
      class << self
        def for_string(max_length: nil, pattern: nil, required: false, sanitize: false, detect_dangerous: true)
          new(type: "string", max_length:, pattern:, required:, sanitize:, detect_dangerous:)
        end

        def for_integer(required: false)
          new(type: "integer", max_length: nil, pattern: nil, required:, sanitize: false, detect_dangerous: false)
        end

        def for_boolean(required: false)
          new(type: "boolean", max_length: nil, pattern: nil, required:, sanitize: false, detect_dangerous: false)
        end

        def for_array(max_length: nil, required: false)
          new(type: "array", max_length:, pattern: nil, required:, sanitize: false, detect_dangerous: false)
        end

        def for_hash(required: false)
          new(type: "hash", max_length: nil, pattern: nil, required:, sanitize: false, detect_dangerous: false)
        end

        def from_spec(spec)
          spec = symbolize_keys(spec)
          type = extract_type(spec)
          new(
            type:,
            max_length: spec[:max_length],
            pattern: spec[:pattern],
            required: !spec[:nullable],
            sanitize: spec[:sanitize] || false,
            detect_dangerous: spec.fetch(:detect_dangerous, type == "string")
          )
        end

        private

        def symbolize_keys(hash)
          hash.transform_keys { |k| k.respond_to?(:to_sym) ? k.to_sym : k }
        end

        def extract_type(spec)
          type = spec[:type]
          type.is_a?(Array) ? type.first : type
        end
      end

      def deconstruct_keys(_) = { type:, max_length:, pattern:, required:, sanitize:, detect_dangerous: }
    end
  end
end
