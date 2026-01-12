require "ripper"

module Smolagents
  module Concerns
    module RubySafety
      DANGEROUS_METHODS = Set.new(%w[
                                    eval instance_eval class_eval module_eval system exec spawn fork
                                    require require_relative load autoload open File IO Dir
                                    send __send__ public_send method define_method
                                    const_get const_set remove_const class_variable_get class_variable_set remove_class_variable
                                    instance_variable_get instance_variable_set remove_instance_variable
                                    binding ObjectSpace Marshal Kernel
                                  ]).freeze

      DANGEROUS_CONSTANTS = Set.new(%w[
                                      File IO Dir Process Thread ObjectSpace Marshal Kernel ENV
                                      FileUtils Pathname Socket TCPSocket UDPSocket BasicSocket
                                      ARGV ARGF DATA RUBY_PLATFORM RUBY_VERSION
                                    ]).freeze

      DANGEROUS_PATTERNS = [/`[^`]+`/, /%x\[/, /%x\{/, /%x\(/].freeze

      DANGEROUS_IMPORTS = %w[FileUtils net/http open-uri socket].freeze

      DANGEROUS_CONSTANT_REGEX = /(?<![A-Za-z0-9_:])(#{DANGEROUS_CONSTANTS.to_a.join("|")})(?![A-Za-z0-9_])/

      # Sexp node types that contain identifiers
      IDENTIFIER_TYPES = %i[@ident @const].freeze

      def validate_ruby_code!(code)
        if (match = code.match(DANGEROUS_CONSTANT_REGEX))
          raise InterpreterError, "Dangerous constant access: #{match[1]}"
        end

        DANGEROUS_PATTERNS.each { |pattern| raise InterpreterError, "Dangerous pattern: #{pattern.inspect}" if code.match?(pattern) }
        DANGEROUS_IMPORTS.each { |import| raise InterpreterError, "Dangerous import: #{import}" if code.match?(/require\s+['"]#{Regexp.escape(import)}['"]/) }

        sexp = Ripper.sexp(code) or raise InterpreterError, "Code has syntax errors"
        check_sexp_safety(sexp)
      end

      def check_sexp_safety(sexp)
        return unless sexp.is_a?(Array)

        if %i[command vcall fcall call].include?(sexp[0])
          method_name = extract_method_name(sexp)
          raise InterpreterError, "Dangerous method call: #{method_name}" if method_name && DANGEROUS_METHODS.include?(method_name)
        end

        if sexp[0] == :var_ref && sexp[1].is_a?(Array) && sexp[1][0] == :@const
          const_name = sexp[1][1]
          raise InterpreterError, "Dangerous constant access: #{const_name}" if DANGEROUS_CONSTANTS.include?(const_name)
        end

        if sexp[0] == :const_path_ref
          const_name = extract_const_path(sexp)
          raise InterpreterError, "Dangerous constant access: #{const_name}" if const_name && DANGEROUS_CONSTANTS.any? { |dc| const_name.start_with?(dc) }
        end

        sexp.each { |child| check_sexp_safety(child) }
      end

      private

      def extract_method_name(sexp)
        sexp.find { |elem| elem.is_a?(Array) && IDENTIFIER_TYPES.include?(elem[0]) }&.[](1)
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
end
