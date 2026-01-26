module Smolagents
  module Security
    VIOLATION_TYPES = %i[
      dangerous_method dangerous_constant backtick_execution
      dangerous_pattern dangerous_import syntax_error
    ].freeze

    VIOLATION_MESSAGES = {
      dangerous_method: "Dangerous method call",
      dangerous_constant: "Dangerous constant access",
      backtick_execution: "Backtick command execution",
      dangerous_pattern: "Dangerous pattern",
      dangerous_import: "Dangerous import",
      syntax_error: "Syntax error"
    }.freeze

    # Immutable validation result with success/failure status and violations.
    ValidationResult = Data.define(:valid, :violations) do
      def self.success = new(valid: true, violations: [].freeze)
      def self.failure(violations:) = new(valid: false, violations: Array(violations).freeze)

      def valid? = valid
      def invalid? = !valid

      def to_error_message
        return nil if valid?

        "Code validation failed:\n#{violations.map { |v| "  - #{v}" }.join("\n")}"
      end
    end

    # Immutable record describing a single code safety violation.
    ValidationViolation = Data.define(:type, :detail, :context) do
      def self.dangerous_method(name, context: nil) = new(type: :dangerous_method, detail: name, context:)
      def self.dangerous_constant(name, context: nil) = new(type: :dangerous_constant, detail: name, context:)
      def self.backtick_execution(context: nil) = new(type: :backtick_execution, detail: "command execution", context:)
      def self.dangerous_pattern(pattern, context: nil) = new(type: :dangerous_pattern, detail: pattern, context:)
      def self.dangerous_import(name, context: nil) = new(type: :dangerous_import, detail: name, context:)
      def self.syntax_error(message) = new(type: :syntax_error, detail: message, context: nil)

      def in_interpolation? = context == :interpolation

      def to_s
        base = format_violation
        context == :interpolation ? "#{base} (in string interpolation)" : base
      end

      private

      def format_violation
        prefix = VIOLATION_MESSAGES.fetch(type, "Unknown violation")
        type == :backtick_execution ? prefix : "#{prefix}: #{detail}"
      end
    end

    # Immutable context for AST traversal during code validation.
    NodeContext = Data.define(:in_interpolation, :depth) do
      def self.root = new(in_interpolation: false, depth: 0)

      def enter_interpolation = with(in_interpolation: true, depth: depth + 1)
      def descend = with(depth: depth + 1)
      def context_type = in_interpolation ? :interpolation : nil
    end
  end
end
