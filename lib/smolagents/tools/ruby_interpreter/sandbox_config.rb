module Smolagents
  module Tools
    class RubyInterpreterTool < Tool
      # Immutable sandbox configuration using Ruby 4.0 Data.define pattern.
      #
      # Encapsulates all settings for the sandboxed Ruby execution environment.
      # Instances are frozen and can be shared across threads safely.
      #
      # @example Creating a config
      #   config = SandboxConfig.new(
      #     timeout_seconds: 30,
      #     max_operations_count: 100_000,
      #     max_output_length_bytes: 50_000,
      #     trace_mode_setting: :line,
      #     authorized_import_list: %w[json time]
      #   )
      #
      # @see SandboxConfigBuilder For a mutable DSL builder
      SandboxConfig = Data.define(
        :timeout_seconds,
        :max_operations_count,
        :max_output_length_bytes,
        :trace_mode_setting,
        :authorized_import_list
      ) do
        # Converts configuration to Hash with canonical key names.
        #
        # @return [Hash{Symbol => Object}] Hash with :timeout, :max_operations,
        #   :max_output_length, :trace_mode, and :authorized_imports keys
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
    end
  end
end
