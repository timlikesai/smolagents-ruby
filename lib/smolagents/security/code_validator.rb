require "ripper"
require_relative "validation_types"
require_relative "allowlists"
require_relative "ast_helpers"

module Smolagents
  module Security
    # AST-based code validator for detecting dangerous Ruby operations.
    module CodeValidator
      include Allowlists
      extend AstHelpers

      module_function

      def validate!(code)
        result = validate(code)
        raise InterpreterError, result.to_error_message if result.invalid?

        result
      end

      def validate(code)
        violations = check_patterns(code) + check_imports(code)
        sexp = Ripper.sexp(code)
        unless sexp
          violations << ValidationViolation.syntax_error("Code has syntax errors")
          return ValidationResult.failure(violations:)
        end

        violations.concat(validate_sexp(sexp, NodeContext.root))
        violations.empty? ? ValidationResult.success : ValidationResult.failure(violations:)
      end

      def check_patterns(code)
        DANGEROUS_PATTERNS.filter_map { ValidationViolation.dangerous_pattern(it.inspect) if code.match?(it) }
      end

      def check_imports(code)
        DANGEROUS_IMPORTS.filter_map do |import|
          ValidationViolation.dangerous_import(import) if code.match?(/require\s+['"]#{Regexp.escape(import)}['"]/)
        end
      end

      def validate_sexp(sexp, context)
        return [] unless sexp.is_a?(Array)
        if context.depth > MAX_AST_DEPTH
          return [ValidationViolation.dangerous_pattern("AST depth exceeded #{MAX_AST_DEPTH}")]
        end

        validate_sexp_node(sexp, context) || sexp.flat_map { |child| validate_sexp(child, context.descend) }
      end

      def validate_sexp_node(sexp, context)
        validate_literal_node(sexp, context) || validate_call_node(sexp, context)
      end

      def validate_literal_node(sexp, context)
        case sexp
        in [:xstring_literal, *] then [ValidationViolation.backtick_execution(context: context.context_type)]
        in [:string_embexpr, *children] then children.flat_map { |c| validate_sexp(c, context.enter_interpolation) }
        in [:var_ref, [:@const, const_name, _]] then validate_const_ref(const_name, context)
        in [:const_path_ref, *] then validate_const_path_ref(sexp, context)
        else nil
        end
      end

      def validate_call_node(sexp, context)
        case sexp
        in [:command | :vcall | :fcall, *] => node then validate_method_call(node, sexp, context)
        in [:call, receiver, _, [:@ident, method_name, _], *] then validate_receiver_call(receiver, method_name,
                                                                                          context)
        else nil
        end
      end

      def validate_method_call(node, sexp, context)
        method_name = extract_method_name(node)
        violations = dangerous_method_violation(method_name, context)
        violations.concat(sexp.flat_map { |child| validate_sexp(child, context.descend) })
      end

      def validate_receiver_call(receiver, method_name, context)
        dangerous_method_violation(method_name, context).concat(validate_sexp(receiver, context.descend))
      end

      def dangerous_method_violation(method_name, context)
        return [] unless method_name && DANGEROUS_METHODS.include?(method_name)

        [ValidationViolation.dangerous_method(method_name, context: context.context_type)]
      end

      def validate_const_ref(const_name, context)
        return [] unless DANGEROUS_CONSTANTS.include?(const_name)

        [ValidationViolation.dangerous_constant(const_name, context: context.context_type)]
      end

      def validate_const_path_ref(sexp, context)
        const_name = extract_const_path(sexp)
        violations = dangerous_const_violation(const_name, context)
        violations.concat(sexp.flat_map { |child| validate_sexp(child, context.descend) })
      end

      def dangerous_const_violation(const_name, context)
        return [] unless const_name && DANGEROUS_CONSTANTS.any? { const_name.start_with?(it) }

        [ValidationViolation.dangerous_constant(const_name, context: context.context_type)]
      end

      def extract_method_name(sexp) = AstHelpers.extract_method_name(sexp)
      def extract_const_path(sexp) = AstHelpers.extract_const_path(sexp)
    end
  end
end
