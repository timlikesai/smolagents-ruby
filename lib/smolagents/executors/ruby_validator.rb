# frozen_string_literal: true

require "ripper"

module Smolagents
  # Ruby code validator using AST analysis. Detects dangerous method calls, requires, and constant access.
  class RubyValidator < Validator
    DANGEROUS_METHODS = Set.new(%w[
      eval instance_eval class_eval module_eval system exec spawn fork
      require require_relative load autoload open File IO Dir
      send __send__ public_send method define_method
      const_get const_set remove_const
      class_variable_get class_variable_set remove_class_variable
      instance_variable_get instance_variable_set remove_instance_variable
      binding ObjectSpace Marshal Kernel
    ]).freeze

    DANGEROUS_CONSTANTS = Set.new(%w[
      File IO Dir Process Thread ObjectSpace Marshal Kernel ENV
      ARGV ARGF DATA RUBY_PLATFORM RUBY_VERSION
    ]).freeze

    DANGEROUS_PATTERNS = [/`[^`]+`/, /%x\[/, /%x\{/, /%x\(/].freeze
    DANGEROUS_IMPORTS = %w[FileUtils net/http open-uri socket].freeze

    def validate(code)
      errors = []
      sexp = Ripper.sexp(code)
      errors << "Ruby code has syntax errors" if sexp.nil?

      DANGEROUS_PATTERNS.each { |p| errors << "Dangerous pattern: #{p.inspect}" if code.match?(p) }
      DANGEROUS_IMPORTS.each { |i| errors << "Dangerous import: #{i}" if code.match?(/require\s+['"]#{Regexp.escape(i)}['"]/) }
      check_sexp_for_dangerous_calls(sexp, errors) if sexp

      ValidationResult.new(valid: errors.empty?, errors: errors, warnings: [])
    end

    def validate!(code)
      result = validate(code)
      raise InterpreterError, result.errors.join("; ") if result.invalid?
    end

    private

    def check_sexp_for_dangerous_calls(sexp, errors)
      return unless sexp.is_a?(Array)

      if %i[command vcall fcall call].include?(sexp[0])
        method_name = extract_method_name(sexp)
        errors << "Dangerous method call: #{method_name}" if method_name && DANGEROUS_METHODS.include?(method_name)
      end

      if sexp[0] == :var_ref && sexp[1].is_a?(Array) && sexp[1][0] == :@const
        const_name = sexp[1][1]
        errors << "Dangerous constant access: #{const_name}" if DANGEROUS_CONSTANTS.include?(const_name)
      end

      if sexp[0] == :const_path_ref
        const_name = extract_const_path(sexp)
        errors << "Dangerous constant access: #{const_name}" if const_name && DANGEROUS_CONSTANTS.any? { |dc| const_name.start_with?(dc) }
      end

      sexp.each { |child| check_sexp_for_dangerous_calls(child, errors) }
    end

    def extract_method_name(sexp)
      sexp.each do |elem|
        return elem[1] if elem.is_a?(Array) && %i[@ident @const].include?(elem[0])
      end
      nil
    end

    def extract_const_path(sexp)
      parts = []
      extract_const_path_parts(sexp, parts)
      parts.join("::") unless parts.empty?
    end

    def extract_const_path_parts(sexp, parts)
      return unless sexp.is_a?(Array)
      parts << sexp[1] if sexp[0] == :@const
      sexp.each { |child| extract_const_path_parts(child, parts) } if %i[const_path_ref].include?(sexp[0]) || !%i[@const].include?(sexp[0])
    end
  end
end
