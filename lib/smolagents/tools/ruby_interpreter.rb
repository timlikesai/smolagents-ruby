module Smolagents
  module Tools
    # Tool for executing Ruby code in a sandboxed environment.
    #
    # RubyInterpreterTool provides safe code execution capabilities for agents,
    # allowing them to perform calculations, data processing, and text manipulation.
    # Code runs in a restricted sandbox with operation limits and timeout protection.
    #
    # The tool captures both stdout output and the final expression value,
    # returning them in a formatted string. Errors are caught and returned
    # as error messages rather than raising exceptions.
    #
    # @example Basic usage with an agent
    #   tool = Smolagents::RubyInterpreterTool.new
    #   result = tool.call(code: "2 + 2")
    #   # => ToolResult with data: "Stdout:\n\nOutput: 4"
    #
    # @example Executing code with output
    #   tool = Smolagents::RubyInterpreterTool.new
    #   result = tool.call(code: <<~RUBY)
    #     puts "Processing..."
    #     numbers = [1, 2, 3, 4, 5]
    #     numbers.map { |n| n * 2 }.sum
    #   RUBY
    #   # => ToolResult with data: "Stdout:\nProcessing...\nOutput: 30"
    #
    # @example Configuring sandbox via DSL
    #   class RestrictedRubyTool < RubyInterpreterTool
    #     sandbox do
    #       timeout 10
    #       max_operations 10_000
    #       authorized_imports %w[json date]
    #     end
    #   end
    #
    # @example Configuring sandbox at instance level
    #   tool = RubyInterpreterTool.new(
    #     timeout: 5,
    #     max_operations: 5_000,
    #     authorized_imports: %w[json]
    #   )
    #
    # @see LocalRubyExecutor The underlying executor that runs the code
    # @see Tool Base class providing the tool interface
    class RubyInterpreterTool < Tool
      self.tool_name = "ruby"
      self.description = <<~DESC.strip
        Execute Ruby code for calculations, data processing, or text manipulation.
        Code runs in a sandboxed environment with timeout and operation limits.

        Use when: You need to perform calculations, transform data, or manipulate strings.
        Do NOT use: For web requests, file I/O, or system commands - use dedicated tools.

        Returns: The stdout output and final expression value, or an error message.
      DESC
      self.inputs = { code: { type: "string", description: "Ruby code to execute" } }
      self.output_type = "string"

      # Immutable sandbox configuration (Ruby 4.0 Data.define pattern)
      SandboxConfig = Data.define(
        :timeout_seconds,
        :max_operations_count,
        :max_output_length_bytes,
        :trace_mode_setting,
        :authorized_import_list
      ) do
        # Converts sandbox configuration to a Hash for use in initialization.
        #
        # @return [Hash{Symbol => Object}] Hash with :timeout, :max_operations, :max_output_length,
        #   :trace_mode, and :authorized_imports keys
        #
        # @example
        #   config = SandboxConfig.new(timeout_seconds: 10, max_operations_count: 5_000, ...)
        #   config.to_h
        #   # => { timeout: 10, max_operations: 5_000, ... }
        def to_h
          {
            timeout: timeout_seconds,
            max_operations: max_operations_count,
            max_output_length: max_output_length_bytes,
            trace_mode: trace_mode_setting,
            authorized_imports: authorized_import_list
          }
        end
      end

      # Mutable DSL builder for sandbox configure blocks
      class SandboxConfigBuilder
        def initialize
          @settings = {
            timeout_seconds: 30,
            max_operations_count: Executor::DEFAULT_MAX_OPERATIONS,
            max_output_length_bytes: Executor::DEFAULT_MAX_OUTPUT_LENGTH,
            trace_mode_setting: :line,
            authorized_import_list: nil
          }
        end

        # Sets the execution timeout in seconds.
        #
        # @param seconds [Integer] Timeout duration in seconds
        # @return [Integer] The timeout that was set
        #
        # @example
        #   builder.timeout(10)
        def timeout(seconds) = @settings[:timeout_seconds] = seconds

        # Sets the maximum number of operations before forced termination.
        #
        # @param count [Integer] Maximum operation count
        # @return [Integer] The count that was set
        #
        # @example
        #   builder.max_operations(50_000)
        def max_operations(count) = @settings[:max_operations_count] = count

        # Sets the maximum output length in bytes before truncation.
        #
        # @param bytes [Integer] Maximum output length in bytes
        # @return [Integer] The length that was set
        #
        # @example
        #   builder.max_output_length(100_000)
        def max_output_length(bytes) = @settings[:max_output_length_bytes] = bytes

        # Sets the operation tracing mode for monitoring execution.
        #
        # @param mode [Symbol] Tracing mode (:line for line tracing, :call for call tracing)
        # @return [Symbol] The mode that was set
        #
        # @example
        #   builder.trace_mode(:call)
        def trace_mode(mode) = @settings[:trace_mode_setting] = mode

        # Sets the list of authorized library imports.
        #
        # These are mentioned in the tool description to inform agents of available libraries.
        # This does not enforce import restrictions, only communicates capability.
        #
        # @param imports [Array<String>] List of authorized library names
        # @return [Array<String>] The imports that were set
        #
        # @example
        #   builder.authorized_imports(%w[json yaml csv])
        def authorized_imports(imports) = @settings[:authorized_import_list] = imports

        # Builds the immutable SandboxConfig from current settings.
        #
        # @return [SandboxConfig] An immutable configuration object
        #
        # @example
        #   builder.max_operations(10_000)
        #   config = builder.build
        #   # => SandboxConfig with max_operations_count=10_000
        def build = SandboxConfig.new(**@settings)
      end

      class << self
        # DSL block for configuring sandbox settings at the class level.
        #
        # @example
        #   class MyRubyTool < RubyInterpreterTool
        #     sandbox do |config|
        #       config.timeout 10
        #       config.max_operations 50_000
        #       config.authorized_imports %w[json yaml]
        #     end
        #   end
        #
        # @yield [config] Configuration block with explicit builder parameter
        # @yieldparam config [SandboxConfigBuilder] The sandbox configuration builder
        # @return [SandboxConfig] The sandbox configuration
        def sandbox(&block)
          builder = SandboxConfigBuilder.new
          block&.call(builder)
          @sandbox_config = builder.build
        end

        # Returns the sandbox configuration, inheriting from parent if not set.
        # @return [SandboxConfig] Always returns a SandboxConfig (creates default if needed)
        def sandbox_config
          @sandbox_config ||
            (superclass.sandbox_config if superclass.respond_to?(:sandbox_config)) ||
            SandboxConfigBuilder.new.build
        end
      end

      # @return [Hash] Input specifications including allowed libraries
      attr_reader :inputs

      # @return [Integer] Execution timeout in seconds
      attr_reader :timeout

      # @return [Array<String>] Authorized imports for description
      attr_reader :authorized_imports

      # Creates a new Ruby interpreter tool.
      #
      # @param timeout [Integer] Execution timeout in seconds (default: 30)
      # @param max_operations [Integer] Maximum operations before timeout (default: 100_000)
      # @param max_output_length [Integer] Maximum output bytes (default: 50_000)
      # @param trace_mode [Symbol] Operation tracing mode (:line or :call)
      # @param authorized_imports [Array<String>, nil] List of allowed library names
      #   to mention in the tool description. Defaults to {Configuration::DEFAULT_AUTHORIZED_IMPORTS}.
      #   Note: This affects the description shown to agents but does not enforce restrictions.
      #
      # @example Default configuration
      #   tool = RubyInterpreterTool.new
      #
      # @example Custom sandbox settings
      #   tool = RubyInterpreterTool.new(
      #     timeout: 10,
      #     max_operations: 10_000,
      #     authorized_imports: %w[json yaml csv]
      #   )
      def initialize(timeout: nil, max_operations: nil, max_output_length: nil, trace_mode: nil,
                     authorized_imports: nil)
        resolve_config(timeout:, max_operations:, max_output_length:, trace_mode:, authorized_imports:)
        @executor = build_executor
        desc = "Ruby code to evaluate. Allowed libraries: #{@authorized_imports.join(", ")}."
        @inputs = { code: { type: "string", description: desc } }
        super()
      end

      CONFIG_DEFAULTS = {
        timeout: 30, max_operations: Executor::DEFAULT_MAX_OPERATIONS,
        max_output_length: Executor::DEFAULT_MAX_OUTPUT_LENGTH, trace_mode: :line,
        authorized_imports: Configuration::DEFAULT_AUTHORIZED_IMPORTS
      }.freeze
      private_constant :CONFIG_DEFAULTS

      private

      def resolve_config(timeout:, max_operations:, max_output_length:, trace_mode:, authorized_imports:)
        provided = { timeout:, max_operations:, max_output_length:, trace_mode:, authorized_imports: }.compact
        cfg = CONFIG_DEFAULTS.merge(self.class.sandbox_config.to_h.compact).merge(provided)
        cfg.each { |key, value| instance_variable_set(:"@#{key}", value) }
      end

      def build_executor
        LocalRubyExecutor.new(max_operations: @max_operations,
                              max_output_length: @max_output_length, trace_mode: @trace_mode)
      end

      public

      # Executes Ruby code and returns the result.
      #
      # The code runs in a sandboxed environment with configured timeout.
      # Both stdout output and the final expression value are captured.
      #
      # @param code [String] Ruby code to execute
      # @return [String] Formatted result containing stdout and output value,
      #   or an error message if execution failed
      #
      # @example Successful execution
      #   execute(code: "[1,2,3].sum")
      #   # => "Stdout:\n\nOutput: 6"
      #
      # @example Execution with stdout
      #   execute(code: "puts 'hello'; 42")
      #   # => "Stdout:\nhello\nOutput: 42"
      #
      # @example Failed execution
      #   execute(code: "raise 'oops'")
      #   # => "Error: RuntimeError: oops"
      def execute(code:)
        result = @executor.execute(code, language: :ruby, timeout: @timeout)
        result.success? ? "Stdout:\n#{result.logs}\nOutput: #{result.output}" : "Error: #{result.error}"
      end
    end
  end

  # Re-export RubyInterpreterTool at the Smolagents level for backward compatibility.
  # @see Smolagents::Tools::RubyInterpreterTool
  RubyInterpreterTool = Tools::RubyInterpreterTool
end
