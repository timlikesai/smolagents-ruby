module Smolagents
  module Security
    # Main validation logic for tool arguments.
    module ArgumentValidator
      class << self
        def validate(value, rule)
          return handle_nil(rule) if value.nil?

          errors = collect_errors(value, rule)
          return ArgumentValidationResult.failure(errors:) if errors.any?

          sanitized = rule.sanitize ? DangerDetector.sanitize(value) : value
          ArgumentValidationResult.success(sanitized_value: sanitized)
        end

        def validate_all(arguments, input_specs)
          arguments = symbolize_keys(arguments)
          input_specs = symbolize_keys(input_specs)
          input_specs.to_h do |name, spec|
            rule = ValidationRule.from_spec(spec)
            [name, validate(arguments[name], rule)]
          end
        end

        def validate_all!(arguments, input_specs, tool_name:)
          results = validate_all(arguments, input_specs)
          failures = results.select { |_, r| r.invalid? }.transform_values(&:errors)

          raise Errors::ArgumentValidationError.new(failures:, tool_name:) if failures.any?

          results.transform_values(&:sanitized_value)
        end

        private

        def handle_nil(rule)
          return ArgumentValidationResult.failure(errors: ["is required"]) if rule.required

          ArgumentValidationResult.success(sanitized_value: nil)
        end

        # rubocop:disable Metrics/AbcSize -- validation requires multiple checks
        def collect_errors(value, rule)
          errors = []
          errors << TypeValidator.type_error(rule.type) unless TypeValidator.valid_type?(value, rule.type)
          return errors if errors.any?

          errors << TypeValidator.check_length(value, rule.max_length, rule.type)
          errors << TypeValidator.check_pattern(value, rule.pattern)
          errors.concat(DangerDetector.detect(value)) if rule.detect_dangerous
          errors.compact
        end
        # rubocop:enable Metrics/AbcSize

        def symbolize_keys(hash)
          hash.transform_keys { |k| k.respond_to?(:to_sym) ? k.to_sym : k }
        end
      end
    end
  end
end
