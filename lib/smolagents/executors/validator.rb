# frozen_string_literal: true

module Smolagents
  # Abstract base class for code validators.
  class Validator
    ValidationResult = Data.define(:valid, :errors, :warnings) do
      def initialize(valid: true, errors: [], warnings: []) = super
      def valid? = valid
      def invalid? = !valid
      def has_warnings? = !warnings.empty?
    end

    def validate!(code)
      result = validate(code)
      raise InterpreterError, result.errors.join(", ") if result.invalid?
    end

    def validate(code)
      errors = []
      dangerous_patterns.each { |p| (p.is_a?(Regexp) ? code.match(p) : code.include?(p.to_s)) && (errors << (p.is_a?(Regexp) ? "Dangerous pattern: #{code.match(p)[0]}" : "Dangerous keyword: #{p}")) }
      dangerous_imports.each { |i| errors << "Dangerous import: #{i}" if check_import(code, i) }
      ValidationResult.new(valid: errors.empty?, errors: errors, warnings: [])
    end

    protected

    def dangerous_patterns = []
    def dangerous_imports = []
    def check_import(_code, _import) = false
  end
end
