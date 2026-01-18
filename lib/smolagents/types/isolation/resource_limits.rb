module Smolagents
  module Types
    module Isolation
      # Default timeout in seconds for isolated execution.
      DEFAULT_TIMEOUT_SECONDS = 5.0

      # Default maximum memory in bytes (50MB).
      DEFAULT_MAX_MEMORY_BYTES = 50 * 1024 * 1024

      # Default maximum output in bytes (50KB).
      DEFAULT_MAX_OUTPUT_BYTES = 50 * 1024

      # Resource limits for isolated tool execution.
      #
      # Defines the boundaries for sandboxed execution including timeout,
      # memory usage, and output size. Used by executors to enforce
      # resource constraints and prevent runaway tool execution.
      #
      # @example Using defaults
      #   limits = ResourceLimits.default
      #   limits.timeout_seconds  # => 5.0
      #   limits.max_memory_bytes # => 52_428_800 (50MB)
      #
      # @example Custom limits for compute-heavy tools
      #   limits = ResourceLimits.new(
      #     timeout_seconds: 30.0,
      #     max_memory_bytes: 100 * 1024 * 1024,
      #     max_output_bytes: 100 * 1024
      #   )
      #
      # @see ResourceMetrics For measuring actual usage
      # @see IsolationResult For execution outcomes
      ResourceLimits = Data.define(:timeout_seconds, :max_memory_bytes, :max_output_bytes) do
        include TypeSupport::Deconstructable

        # Creates default resource limits.
        #
        # @return [ResourceLimits] Limits with standard defaults
        def self.default
          new(
            timeout_seconds: DEFAULT_TIMEOUT_SECONDS,
            max_memory_bytes: DEFAULT_MAX_MEMORY_BYTES,
            max_output_bytes: DEFAULT_MAX_OUTPUT_BYTES
          )
        end

        # Creates resource limits with a custom timeout.
        #
        # @param seconds [Float] Timeout in seconds
        # @return [ResourceLimits] Limits with custom timeout, default memory/output
        def self.with_timeout(seconds)
          new(
            timeout_seconds: seconds,
            max_memory_bytes: DEFAULT_MAX_MEMORY_BYTES,
            max_output_bytes: DEFAULT_MAX_OUTPUT_BYTES
          )
        end

        # Creates permissive limits for trusted tools.
        #
        # @return [ResourceLimits] Higher limits for trusted execution
        def self.permissive
          new(
            timeout_seconds: 60.0,
            max_memory_bytes: 500 * 1024 * 1024, # 500MB
            max_output_bytes: 1024 * 1024        # 1MB
          )
        end

        # Converts to hash for serialization.
        #
        # @return [Hash] Hash with all limit fields
        def to_h = { timeout_seconds:, max_memory_bytes:, max_output_bytes: }
      end
    end
  end
end
