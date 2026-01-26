module Smolagents
  module Executors
    class Executor
      module ToolCallTracking
        # Recorded tool call data.
        TrackedCall = Data.define(:tool_name, :arguments, :result, :duration, :error) do
          def success? = error.nil?
          def to_h = { tool_name:, arguments:, result:, duration:, error: }
        end
      end
    end
  end
end
