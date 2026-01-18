module Smolagents
  module Tools
    class ToolResult
      # Core initialization and data management for ToolResult.
      #
      # Provides the basic constructor, accessors, and immutability helpers.
      module Core
        attr_reader :data, :tool_name, :metadata

        # Creates a new ToolResult wrapping the given data.
        #
        # @param data [Object] The data to wrap (will be deep-frozen)
        # @param tool_name [String, Symbol] Name of the tool that produced this result
        # @param metadata [Hash] Additional metadata to attach
        # @option metadata [Time] :created_at Automatically set to current time
        # @option metadata [Boolean] :success Whether the operation succeeded
        # @option metadata [String] :error Error message if operation failed
        def initialize(data, tool_name:, metadata: {})
          @data = deep_freeze(data)
          @tool_name = tool_name.to_s.freeze
          @metadata = metadata.merge(created_at: Time.now).freeze
        end

        private

        # Deep-freezes an object to ensure immutability.
        def deep_freeze(obj) = Utilities::Transform.freeze(obj)

        # Converts data to an enumerable form.
        #
        # @return [Array, Hash] Enumerable version of the data
        def enumerable_data
          case @data
          when Array, Hash then @data
          when nil then []
          else [@data]
          end
        end

        # Creates a new ToolResult from a transformation, preserving lineage.
        #
        # @param operation [Symbol] Name of the operation performed
        # @yield Block that computes the new data
        # @return [ToolResult] New result with transformed data
        def chain(operation)
          self.class.new(yield, tool_name: @tool_name,
                                metadata: { parent: @metadata[:created_at], op: operation })
        end
      end
    end
  end
end
