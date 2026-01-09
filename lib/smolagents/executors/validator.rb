# frozen_string_literal: true

module Smolagents
  # Abstract base class for code validators.
  # Validators perform static analysis to detect dangerous code patterns.
  #
  # @example Implementing a validator
  #   class MyValidator < Validator
  #     def validate!(code)
  #       raise InterpreterError, "Dangerous!" if code.include?("bad")
  #     end
  #
  #     def dangerous_patterns
  #       [/bad/]
  #     end
  #   end
  class Validator
    # Validation result with warnings and errors.
    ValidationResult = Data.define(:valid, :errors, :warnings) do
      def initialize(valid: true, errors: [], warnings: [])
        super
      end

      def valid? = valid
      def invalid? = !valid
      def has_warnings? = !warnings.empty?
    end

    # Validate code and raise error if dangerous.
    #
    # @param code [String] code to validate
    # @raise [InterpreterError] if code is dangerous
    # @return [void]
    def validate!(code)
      result = validate(code)
      raise InterpreterError, result.errors.join(", ") if result.invalid?
    end

    # Validate code and return result.
    #
    # @param code [String] code to validate
    # @return [ValidationResult]
    def validate(code)
      errors = []
      warnings = []

      # Check for dangerous patterns
      dangerous_patterns.each do |pattern|
        if pattern.is_a?(Regexp)
          if (match = code.match(pattern))
            errors << "Dangerous pattern: #{match[0]}"
          end
        elsif code.include?(pattern.to_s)
          errors << "Dangerous keyword: #{pattern}"
        end
      end

      # Check for dangerous imports/requires
      dangerous_imports.each do |import|
        errors << "Dangerous import: #{import}" if check_import(code, import)
      end

      ValidationResult.new(
        valid: errors.empty?,
        errors: errors,
        warnings: warnings
      )
    end

    protected

    # List of dangerous patterns to check.
    # Subclasses should override.
    #
    # @return [Array<String, Regexp>]
    def dangerous_patterns
      []
    end

    # List of dangerous imports to check.
    # Subclasses should override.
    #
    # @return [Array<String>]
    def dangerous_imports
      []
    end

    # Check if code imports a dangerous module.
    # Subclasses should override for language-specific import detection.
    #
    # @param code [String] code to check
    # @param import [String] import name
    # @return [Boolean]
    def check_import(_code, _import)
      false
    end
  end
end
