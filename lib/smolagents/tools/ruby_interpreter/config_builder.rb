module Smolagents
  module Tools
    class RubyInterpreterTool < Tool
      # Mutable DSL builder for sandbox configuration.
      #
      # Provides a fluent interface for configuring sandbox settings
      # via block DSL. Builds an immutable {SandboxConfig} on completion.
      #
      # @example Using the builder
      #   builder = SandboxConfigBuilder.new
      #   builder.timeout(60)
      #   builder.max_operations(200_000)
      #   config = builder.build
      #
      # @see SandboxConfig The immutable config produced by this builder
      class SandboxConfigBuilder
        # Default configuration values
        DEFAULTS = {
          timeout_seconds: 30,
          max_operations_count: Executor::DEFAULT_MAX_OPERATIONS,
          max_output_length_bytes: Executor::DEFAULT_MAX_OUTPUT_LENGTH,
          trace_mode_setting: :line,
          authorized_import_list: nil
        }.freeze

        def initialize
          @settings = DEFAULTS.dup
        end

        # Sets the execution timeout in seconds.
        #
        # @param seconds [Integer] Timeout duration in seconds
        # @return [Integer] The timeout that was set
        def timeout(seconds) = @settings[:timeout_seconds] = seconds

        # Sets the maximum number of operations before forced termination.
        #
        # @param count [Integer] Maximum operation count
        # @return [Integer] The count that was set
        def max_operations(count) = @settings[:max_operations_count] = count

        # Sets the maximum output length in bytes before truncation.
        #
        # @param bytes [Integer] Maximum output length in bytes
        # @return [Integer] The length that was set
        def max_output_length(bytes) = @settings[:max_output_length_bytes] = bytes

        # Sets the operation tracing mode for monitoring execution.
        #
        # @param mode [Symbol] Tracing mode (:line for line tracing, :call for call tracing)
        # @return [Symbol] The mode that was set
        def trace_mode(mode) = @settings[:trace_mode_setting] = mode

        # Sets the list of authorized library imports.
        #
        # These are mentioned in the tool description to inform agents of available libraries.
        # This does not enforce import restrictions, only communicates capability.
        #
        # @param imports [Array<String>] List of authorized library names
        # @return [Array<String>] The imports that were set
        def authorized_imports(imports) = @settings[:authorized_import_list] = imports

        # Builds the immutable SandboxConfig from current settings.
        #
        # @return [SandboxConfig] An immutable configuration object
        def build = SandboxConfig.new(**@settings)
      end
    end
  end
end
