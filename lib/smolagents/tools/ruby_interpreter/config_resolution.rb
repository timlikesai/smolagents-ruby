module Smolagents
  module Tools
    class RubyInterpreterTool < Tool
      # Instance-level configuration resolution.
      #
      # Handles merging of default, class-level, and instance-level
      # configuration with proper precedence ordering.
      module ConfigResolution
        # Default configuration values for the interpreter.
        CONFIG_DEFAULTS = {
          timeout: 30,
          max_operations: Executor::DEFAULT_MAX_OPERATIONS,
          max_output_length: Executor::DEFAULT_MAX_OUTPUT_LENGTH,
          trace_mode: :line,
          authorized_imports: Configuration::DEFAULT_AUTHORIZED_IMPORTS
        }.freeze

        private

        # Resolves configuration from defaults, class config, and provided values.
        #
        # Priority (highest to lowest):
        # 1. Explicitly provided arguments
        # 2. Class-level sandbox configuration
        # 3. CONFIG_DEFAULTS
        #
        # @param timeout [Integer, nil] Execution timeout in seconds
        # @param max_operations [Integer, nil] Maximum operations before timeout
        # @param max_output_length [Integer, nil] Maximum output bytes
        # @param trace_mode [Symbol, nil] Operation tracing mode
        # @param authorized_imports [Array<String>, nil] Allowed library names
        # @return [void]
        def resolve_config(timeout:, max_operations:, max_output_length:, trace_mode:, authorized_imports:)
          provided = { timeout:, max_operations:, max_output_length:, trace_mode:, authorized_imports: }.compact
          cfg = CONFIG_DEFAULTS.merge(self.class.sandbox_config.to_h.compact).merge(provided)

          @timeout = cfg[:timeout]
          @max_operations = cfg[:max_operations]
          @max_output_length = cfg[:max_output_length]
          @trace_mode = cfg[:trace_mode]
          @authorized_imports = cfg[:authorized_imports]
        end
      end
    end
  end
end
