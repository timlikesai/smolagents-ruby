module Smolagents
  module Concerns
    module Isolation
      # Builds violation information for resource limit violations.
      #
      # Analyzes metrics against limits to determine which resource was
      # violated and constructs a descriptive info hash for callbacks
      # and event emission.
      #
      # @example Building violation info
      #   info = ViolationInfoBuilder.build("search", metrics, limits)
      #   info[:resource_type]  # => :memory
      #   info[:limit_value]    # => 52_428_800
      #   info[:actual_value]   # => 60_000_000
      #
      # @see ToolIsolation For usage context
      module ViolationInfoBuilder
        # Builds a violation info hash from metrics and limits.
        #
        # @param tool_name [String] Name of the tool that violated limits
        # @param metrics [Types::Isolation::ResourceMetrics] Captured metrics
        # @param limits [Types::Isolation::ResourceLimits] Configured limits
        # @return [Hash] Violation information
        def self.build(tool_name, metrics, limits)
          resource_type = detect_type(metrics, limits)
          {
            tool_name:,
            resource_type:,
            limit_value: limit_for(limits, resource_type),
            actual_value: actual_for(metrics, resource_type),
            message: "#{resource_type} limit exceeded"
          }
        end

        def self.detect_type(metrics, limits)
          return :timeout unless metrics.duration_within?(limits)
          return :memory unless metrics.memory_within?(limits)

          :output
        end

        def self.limit_for(limits, type)
          case type
          when :timeout then limits.timeout_seconds * 1000
          when :memory then limits.max_memory_bytes
          when :output then limits.max_output_bytes
          end
        end

        def self.actual_for(metrics, type)
          case type
          when :timeout then metrics.duration_ms
          when :memory then metrics.memory_bytes
          when :output then metrics.output_bytes
          end
        end
      end
    end
  end
end
