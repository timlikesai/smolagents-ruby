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
    module RubySafety
      # All possible violation types detected by the validator
      VIOLATION_TYPES = %i[
        dangerous_method dangerous_constant backtick_execution
        dangerous_pattern dangerous_import syntax_error
      ].freeze

      # Immutable validation result containing success/failure status and violations.
      #
      # Encapsulates the result of code safety validation with methods
      # for checking success and generating error messages.
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
        # Create a successful validation result (no violations).
        #
        # @return [ValidationResult] Success result with empty violations list
        def self.success = new(valid: true, violations: [].freeze)

        # Create a failed validation result with violations.
        #
        # @param violations [ValidationViolation, Array<ValidationViolation>] Violation(s) found
        # @return [ValidationResult] Failure result with violations
        def self.failure(violations:)
          violations_array = Array(violations).freeze
          new(valid: false, violations: violations_array)
        end

        # Check if code passed validation.
        #
        # @return [Boolean] True if no violations found
        def valid? = valid

        # Check if code failed validation.
        #
        # @return [Boolean] True if violations were found
        def invalid? = !valid

        # Format violations as a human-readable error message.
        #
        # @return [String, nil] Error message with bullet-pointed violations, or nil if valid
        #
        # @example
        #   result = validate_ruby_code("File.read('/etc/passwd')")
        #   result.to_error_message
        #   # => "Code validation failed:\n  • Dangerous constant access: File\n  • ..."
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
      #   @return [Symbol] Violation category (:dangerous_method, :dangerous_constant, :backtick_execution, :dangerous_pattern, :dangerous_import, :syntax_error)
      # @!attribute [r] detail
      #   @return [String] Specific name or pattern that triggered the violation (e.g., "File" for dangerous constant)
      # @!attribute [r] context
      #   @return [Symbol, nil] Where violation occurred (:interpolation for violations in string interpolation, nil otherwise)
      ValidationViolation = Data.define(:type, :detail, :context) do
        # Create a dangerous method call violation.
        #
        # @param name [String] Method name (e.g., "eval", "system", "require")
        # @param context [Symbol, nil] Violation context (:interpolation or nil)
        # @return [ValidationViolation] Violation record
        #
        # @example
        #   ValidationViolation.dangerous_method("eval")
        #   # => ValidationViolation(type: :dangerous_method, detail: "eval", context: nil)
        def self.dangerous_method(name, context: nil)
          new(type: :dangerous_method, detail: name, context:)
        end

        # Create a dangerous constant access violation.
        #
        # @param name [String] Constant name (e.g., "File", "IO", "Process")
        # @param context [Symbol, nil] Violation context (:interpolation or nil)
        # @return [ValidationViolation] Violation record
        def self.dangerous_constant(name, context: nil)
          new(type: :dangerous_constant, detail: name, context:)
        end

        # Create a backtick command execution violation.
        #
        # @param context [Symbol, nil] Violation context (:interpolation or nil)
        # @return [ValidationViolation] Violation record
        #
        # @example
        #   ValidationViolation.backtick_execution
        #   # Detects `whoami` or any backtick shell command
        def self.backtick_execution(context: nil)
          new(type: :backtick_execution, detail: "command execution", context:)
        end

        # Create a dangerous pattern violation.
        #
        # @param pattern [String] Pattern or regex string that was detected
        # @param context [Symbol, nil] Violation context (:interpolation or nil)
        # @return [ValidationViolation] Violation record
        def self.dangerous_pattern(pattern, context: nil)
          new(type: :dangerous_pattern, detail: pattern, context:)
        end

        # Create a dangerous import violation.
        #
        # @param name [String] Library name (e.g., "net/http", "socket", "fileutils")
        # @param context [Symbol, nil] Violation context (:interpolation or nil)
        # @return [ValidationViolation] Violation record
        def self.dangerous_import(name, context: nil)
          new(type: :dangerous_import, detail: name, context:)
        end

        # Create a syntax error violation.
        #
        # @param message [String] Error description
        # @return [ValidationViolation] Violation record
        def self.syntax_error(message)
          new(type: :syntax_error, detail: message, context: nil)
        end

        # Check if this violation occurred in string interpolation.
        #
        # @return [Boolean] True if violation is in interpolated string
        def in_interpolation? = context == :interpolation

        # Format violation as a human-readable string.
        #
        # @return [String] Description including context if in interpolation
        #
        # @example
        #   v = ValidationViolation.dangerous_constant("File")
        #   v.to_s  # => "Dangerous constant access: File"
        #
        # @example With interpolation context
        #   v = ValidationViolation.dangerous_method("eval", context: :interpolation)
        #   v.to_s  # => "Dangerous method call: eval (in string interpolation)"
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

      # Immutable context for AST traversal during code validation.
      #
      # Tracks traversal state while walking the abstract syntax tree,
      # including whether we're inside string interpolation and current depth.
      #
      # @!attribute [r] in_interpolation
      #   @return [Boolean] True if currently traversing inside string interpolation
      # @!attribute [r] depth
      #   @return [Integer] Current AST traversal depth (for cycle detection)
      NodeContext = Data.define(:in_interpolation, :depth) do
        # Create the root AST traversal context.
        #
        # @return [NodeContext] Context for traversing from the top of the AST
        def self.root = new(in_interpolation: false, depth: 0)

        # Descend into string interpolation context.
        #
        # @return [NodeContext] New context with in_interpolation set to true
        #
        # @example
        #   ctx = NodeContext.root
        #   interp_ctx = ctx.enter_interpolation
        #   interp_ctx.in_interpolation?  # => true
        def enter_interpolation = with(in_interpolation: true, depth: depth + 1)

        # Descend one level in AST depth.
        #
        # @return [NodeContext] New context with incremented depth
        def descend = with(depth: depth + 1)

        # Get the current context type for violation reporting.
        #
        # @return [Symbol, nil] :interpolation if in string interpolation, nil otherwise
        def context_type = in_interpolation ? :interpolation : nil
      end

      # @return [Set<String>] Methods that are forbidden in agent code.
      #   Prevents execution of code that could:
      #   - Execute arbitrary code (eval, system, exec)
      #   - Modify process state (fork, exit)
      #   - Access restricted resources (require, load)
      #   - Manipulate object internals (send, method, const_get)
      #   Example methods: eval, system, exec, fork, require, send
      DANGEROUS_METHODS = Set.new(%w[
                                    eval instance_eval class_eval module_eval system exec spawn fork
                                    require require_relative load autoload open File IO Dir
                                    send __send__ public_send method define_method
                                    const_get const_set remove_const class_variable_get class_variable_set remove_class_variable
                                    instance_variable_get instance_variable_set remove_instance_variable
                                    binding ObjectSpace Marshal Kernel
                                    exit exit! abort trap at_exit
                                  ]).freeze

      # @return [Set<String>] Constants that are forbidden in agent code.
      #   Prevents direct access to classes/modules that could:
      #   - Access filesystem (File, IO, Dir)
      #   - Control processes (Process, Thread, Signal)
      #   - Access environment (ENV, ARGV)
      #   - Manipulate object state (ObjectSpace, Marshal)
      #   Example constants: File, IO, Dir, Process, ENV, Socket
      DANGEROUS_CONSTANTS = Set.new(%w[
                                      File IO Dir Process Thread ObjectSpace Marshal Kernel ENV Signal
                                      FileUtils Pathname Socket TCPSocket UDPSocket BasicSocket
                                      ARGV ARGF DATA RUBY_PLATFORM RUBY_VERSION
                                    ]).freeze

      # @return [Array<Regexp>] Regex patterns for detecting command execution syntax.
      #   Matches backtick strings and %x{} percent literals that would execute shell commands.
      #   Example patterns: backticks, %x[], %x{}, %x()
      DANGEROUS_PATTERNS = [/`[^`]+`/, /%x\[/, /%x\{/, /%x\(/].freeze

      # @return [Array<String>] Module names that are forbidden in require statements.
      #   Imports that would bypass sandbox restrictions by accessing:
      #   - Filesystem utilities (FileUtils)
      #   - Network access (net/http, socket)
      #   - File opening (open-uri)
      DANGEROUS_IMPORTS = %w[FileUtils net/http open-uri socket].freeze

      # @return [Array<Symbol>] Sexp node types that contain identifiers in Ruby AST.
      #   Used during AST traversal to find method names and constant references.
      #   @ident marks method identifiers, @const marks constant names.
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
