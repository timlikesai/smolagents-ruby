# frozen_string_literal: true

require "ripper"
require "set"

module Smolagents
  # Ruby code validator using AST analysis.
  # Detects dangerous method calls, requires, and constant access.
  #
  # @example
  #   validator = RubyValidator.new
  #   validator.validate!("puts 'safe'") # OK
  #   validator.validate!("system('rm -rf /')") # raises InterpreterError
  class RubyValidator < Validator
    # Dangerous methods that should be blocked.
    DANGEROUS_METHODS = Set.new(%w[
      eval instance_eval class_eval module_eval
      system exec spawn fork
      require require_relative load autoload
      open File IO Dir
      send __send__ public_send method define_method
      const_get const_set remove_const
      class_variable_get class_variable_set remove_class_variable
      instance_variable_get instance_variable_set remove_instance_variable
      binding
      ObjectSpace Marshal Kernel
    ]).freeze

    # Dangerous constants that should be blocked.
    DANGEROUS_CONSTANTS = Set.new(%w[
      File IO Dir Process Thread ObjectSpace Marshal Kernel ENV
      ARGV ARGF DATA RUBY_PLATFORM RUBY_VERSION
    ]).freeze

    def validate(code)
      errors = []
      warnings = []

      # Check syntax
      sexp = Ripper.sexp(code)
      if sexp.nil?
        errors << "Ruby code has syntax errors"
        return ValidationResult.new(valid: false, errors: errors, warnings: warnings)
      end

      # Check for dangerous patterns (backticks, %x[], etc.)
      dangerous_patterns.each do |pattern|
        if code.match?(pattern)
          errors << "Dangerous pattern: #{pattern.inspect}"
        end
      end

      # Check for dangerous imports
      dangerous_imports.each do |import|
        if check_import(code, import)
          errors << "Dangerous import: #{import}"
        end
      end

      # Check AST for dangerous method calls
      check_sexp_for_dangerous_calls(sexp, errors)

      ValidationResult.new(
        valid: errors.empty?,
        errors: errors,
        warnings: warnings
      )
    end

    def validate!(code)
      result = validate(code)
      raise InterpreterError, result.errors.join("; ") if result.invalid?
    end

    protected

    def dangerous_patterns
      [
        /`[^`]+`/, # Backtick execution
        /%x\[/, # %x[] execution
        /%x\{/, # %x{} execution
        /%x\(/, # %x() execution
      ]
    end

    def dangerous_imports
      %w[FileUtils net/http open-uri socket]
    end

    def check_import(code, import)
      code.match?(/require\s+['"]#{Regexp.escape(import)}['"]/)
    end

    private

    # Recursively check S-expression for dangerous calls.
    #
    # @param sexp [Array, Symbol, String, nil] S-expression
    # @param errors [Array<String>] accumulated errors
    def check_sexp_for_dangerous_calls(sexp, errors)
      return unless sexp.is_a?(Array)

      # Check for dangerous method calls
      if [:command, :vcall, :fcall, :call].include?(sexp[0])
        method_name = extract_method_name(sexp)
        if method_name && DANGEROUS_METHODS.include?(method_name)
          errors << "Dangerous method call: #{method_name}"
        end
      end

      # Check for dangerous constants
      if sexp[0] == :var_ref && sexp[1].is_a?(Array) && sexp[1][0] == :@const
        const_name = sexp[1][1]
        if DANGEROUS_CONSTANTS.include?(const_name)
          errors << "Dangerous constant access: #{const_name}"
        end
      end

      # Check for const_path_ref (e.g., File::SEPARATOR)
      if sexp[0] == :const_path_ref
        const_name = extract_const_path(sexp)
        if const_name && DANGEROUS_CONSTANTS.any? { |dc| const_name.start_with?(dc) }
          errors << "Dangerous constant access: #{const_name}"
        end
      end

      # Recursively check children
      sexp.each { |child| check_sexp_for_dangerous_calls(child, errors) }
    end

    # Extract method name from S-expression.
    #
    # @param sexp [Array] S-expression
    # @return [String, nil]
    def extract_method_name(sexp)
      sexp.each do |elem|
        return elem[1] if elem.is_a?(Array) && elem[0] == :@ident
        return elem[1] if elem.is_a?(Array) && elem[0] == :@const
      end
      nil
    end

    # Extract constant path from S-expression.
    #
    # @param sexp [Array] S-expression
    # @return [String, nil]
    def extract_const_path(sexp)
      parts = []
      extract_const_path_parts(sexp, parts)
      parts.join("::") unless parts.empty?
    end

    def extract_const_path_parts(sexp, parts)
      return unless sexp.is_a?(Array)

      if sexp[0] == :@const
        parts << sexp[1]
      elsif sexp[0] == :const_path_ref
        sexp.each { |child| extract_const_path_parts(child, parts) }
      else
        sexp.each { |child| extract_const_path_parts(child, parts) }
      end
    end
  end
end
