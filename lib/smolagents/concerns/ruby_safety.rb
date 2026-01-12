require "ripper"

module Smolagents
  module Concerns
    # Static code analysis concern for validating Ruby code safety.
    #
    # Performs AST-based analysis to detect dangerous operations before
    # code execution. Used by CodeAgent and RubyInterpreterTool to prevent
    # agent-generated code from performing harmful operations.
    #
    # @example Validating code before execution
    #   class MyExecutor
    #     include Concerns::RubySafety
    #
    #     def execute(code)
    #       validate_ruby_code!(code)  # Raises on dangerous code
    #       eval(code, safe_binding)
    #     end
    #   end
    #
    # @example Getting detailed validation results
    #   result = validate_ruby_code("File.read('/etc/passwd')")
    #   result.valid?      # => false
    #   result.violations  # => [ValidationViolation(type: :dangerous_constant, ...)]
    #
    # @example Understanding violation context
    #   # Dangerous code in string interpolation is also detected:
    #   validate_ruby_code('"#{`whoami`}"')
    #   # => ValidationViolation with context: :interpolation
    #
    # Detection categories:
    # - Dangerous methods: eval, system, exec, fork, require, send, etc.
    # - Dangerous constants: File, IO, Dir, Process, ENV, Marshal, etc.
    # - Command execution: backticks, %x{}, system calls
    # - Dangerous patterns: shell command patterns
    # - Dangerous imports: net/http, socket, fileutils
    #
    # @see ValidationResult Immutable result with violation list
    # @see ValidationViolation Detailed violation information
    module RubySafety # rubocop:disable Metrics/ModuleLength
      # All possible violation types detected by the validator
      VIOLATION_TYPES = %i[
        dangerous_method dangerous_constant backtick_execution
        dangerous_pattern dangerous_import syntax_error
      ].freeze

      # Immutable validation result containing success/failure status and violations.
      #
      # @example Checking validation result
      #   result = validate_ruby_code(code)
      #   if result.valid?
      #     execute(code)
      #   else
      #     puts result.to_error_message
      #   end
      #
      # @!attribute [r] valid
      #   @return [Boolean] True if code passed all safety checks
      # @!attribute [r] violations
      #   @return [Array<ValidationViolation>] List of detected violations (frozen)
      ValidationResult = Data.define(:valid, :violations) do
        def self.success = new(valid: true, violations: [].freeze)

        def self.failure(violations:)
          violations_array = Array(violations).freeze
          new(valid: false, violations: violations_array)
        end

        def valid? = valid
        def invalid? = !valid

        def to_error_message
          return nil if valid?

          "Code validation failed:\n#{violations.map { |v| "  • #{v}" }.join("\n")}"
        end
      end

      # Immutable record describing a single code safety violation.
      #
      # Provides factory methods for each violation type and formats
      # violations for error messages.
      #
      # @!attribute [r] type
      #   @return [Symbol] Violation category (see VIOLATION_TYPES)
      # @!attribute [r] detail
      #   @return [String] Specific name or pattern that triggered the violation
      # @!attribute [r] context
      #   @return [Symbol, nil] Where violation occurred (:interpolation or nil)
      ValidationViolation = Data.define(:type, :detail, :context) do
        def self.dangerous_method(name, context: nil)
          new(type: :dangerous_method, detail: name, context:)
        end

        def self.dangerous_constant(name, context: nil)
          new(type: :dangerous_constant, detail: name, context:)
        end

        def self.backtick_execution(context: nil)
          new(type: :backtick_execution, detail: "command execution", context:)
        end

        def self.dangerous_pattern(pattern, context: nil)
          new(type: :dangerous_pattern, detail: pattern, context:)
        end

        def self.dangerous_import(name, context: nil)
          new(type: :dangerous_import, detail: name, context:)
        end

        def self.syntax_error(message)
          new(type: :syntax_error, detail: message, context: nil)
        end

        def in_interpolation? = context == :interpolation

        def to_s
          base = case type
                 when :dangerous_method then "Dangerous method call: #{detail}"
                 when :dangerous_constant then "Dangerous constant access: #{detail}"
                 when :backtick_execution then "Backtick command execution"
                 when :dangerous_pattern then "Dangerous pattern: #{detail}"
                 when :dangerous_import then "Dangerous import: #{detail}"
                 when :syntax_error then "Syntax error: #{detail}"
                 else "Unknown violation: #{detail}"
                 end
          context == :interpolation ? "#{base} (in string interpolation)" : base
        end
      end

      # Immutable context for AST traversal
      NodeContext = Data.define(:in_interpolation, :depth) do
        def self.root = new(in_interpolation: false, depth: 0)

        def enter_interpolation = with(in_interpolation: true, depth: depth + 1)
        def descend = with(depth: depth + 1)
        def context_type = in_interpolation ? :interpolation : nil
      end

      DANGEROUS_METHODS = Set.new(%w[
                                    eval instance_eval class_eval module_eval system exec spawn fork
                                    require require_relative load autoload open File IO Dir
                                    send __send__ public_send method define_method
                                    const_get const_set remove_const class_variable_get class_variable_set remove_class_variable
                                    instance_variable_get instance_variable_set remove_instance_variable
                                    binding ObjectSpace Marshal Kernel
                                    exit exit! abort trap at_exit
                                  ]).freeze

      DANGEROUS_CONSTANTS = Set.new(%w[
                                      File IO Dir Process Thread ObjectSpace Marshal Kernel ENV Signal
                                      FileUtils Pathname Socket TCPSocket UDPSocket BasicSocket
                                      ARGV ARGF DATA RUBY_PLATFORM RUBY_VERSION
                                    ]).freeze

      DANGEROUS_PATTERNS = [/`[^`]+`/, /%x\[/, /%x\{/, /%x\(/].freeze
      # Imports that would bypass sandbox restrictions
      DANGEROUS_IMPORTS = %w[FileUtils net/http open-uri socket].freeze

      # Sexp node types that contain identifiers (used in AST traversal)
      IDENTIFIER_TYPES = %i[@ident @const].freeze

      # Validates Ruby code and raises on any safety violation.
      #
      # Use this method when you want execution to stop on unsafe code.
      #
      # @param code [String] Ruby source code to validate
      # @return [ValidationResult] Successful validation result
      # @raise [InterpreterError] If code contains dangerous operations
      def validate_ruby_code!(code)
        result = validate_ruby_code(code)
        raise InterpreterError, result.to_error_message if result.invalid?

        result
      end

      # Validates Ruby code and returns a detailed result.
      #
      # Performs multi-pass validation:
      # 1. Quick regex check for dangerous patterns (backticks, %x{})
      # 2. Check for dangerous require statements
      # 3. Parse code to AST using Ripper
      # 4. Walk AST to detect dangerous method calls and constant access
      #
      # @param code [String] Ruby source code to validate
      # @return [ValidationResult] Result with valid? status and violations list
      def validate_ruby_code(code)
        violations = []

        # Check for dangerous top-level patterns (quick regex check)
        DANGEROUS_PATTERNS.each do |pattern|
          violations << ValidationViolation.dangerous_pattern(pattern.inspect) if code.match?(pattern)
        end

        # Check for dangerous imports
        DANGEROUS_IMPORTS.each do |import|
          violations << ValidationViolation.dangerous_import(import) if code.match?(/require\s+['"]#{Regexp.escape(import)}['"]/)
        end

        # Parse and validate AST
        sexp = Ripper.sexp(code)
        unless sexp
          violations << ValidationViolation.syntax_error("Code has syntax errors")
          return ValidationResult.failure(violations:)
        end

        # Walk AST with context tracking
        ast_violations = validate_sexp(sexp, NodeContext.root)
        violations.concat(ast_violations)

        violations.empty? ? ValidationResult.success : ValidationResult.failure(violations:)
      end

      private

      def validate_sexp(sexp, context)
        return [] unless sexp.is_a?(Array)

        case sexp
        in [:xstring_literal, *]
          [ValidationViolation.backtick_execution(context: context.context_type)]
        in [:string_embexpr, *children]
          validate_interpolation(children, context)
        in [:command | :vcall | :fcall, *] => node
          validate_method_call(node, sexp, context)
        in [:call, receiver, _, [:@ident, method_name, _], *]
          validate_receiver_call(receiver, method_name, context)
        in [:var_ref, [:@const, const_name, _]]
          validate_const_ref(const_name, context)
        in [:const_path_ref, *]
          validate_const_path_ref(sexp, context)
        else
          sexp.flat_map { |child| validate_sexp(child, context.descend) }
        end
      end

      def validate_interpolation(children, context)
        interp_context = context.enter_interpolation
        children.flat_map { |child| validate_sexp(child, interp_context) }
      end

      def validate_method_call(node, sexp, context)
        violations = []
        method_name = extract_method_name(node)
        violations << ValidationViolation.dangerous_method(method_name, context: context.context_type) if method_name && DANGEROUS_METHODS.include?(method_name)
        violations.concat(sexp.flat_map { |child| validate_sexp(child, context.descend) })
        violations
      end

      def validate_receiver_call(receiver, method_name, context)
        violations = []
        violations << ValidationViolation.dangerous_method(method_name, context: context.context_type) if DANGEROUS_METHODS.include?(method_name)
        violations.concat(validate_sexp(receiver, context.descend))
        violations
      end

      def validate_const_ref(const_name, context)
        return [] unless DANGEROUS_CONSTANTS.include?(const_name)

        [ValidationViolation.dangerous_constant(const_name, context: context.context_type)]
      end

      def validate_const_path_ref(sexp, context)
        violations = []
        const_name = extract_const_path(sexp)
        if const_name && DANGEROUS_CONSTANTS.any? { |dc| const_name.start_with?(dc) }
          violations << ValidationViolation.dangerous_constant(const_name, context: context.context_type)
        end
        violations.concat(sexp.flat_map { |child| validate_sexp(child, context.descend) })
        violations
      end

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
        return unless %i[const_path_ref].include?(sexp[0]) || !%i[@const].include?(sexp[0])

        sexp.each { |child| extract_const_path_parts(child, parts) }
      end
    end
  end
end
