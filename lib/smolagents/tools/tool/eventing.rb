module Smolagents
  module Tools
    class Tool
      # Event emission for tool execution.
      #
      # Provides event emission around tool calls for observability.
      # Emits ToolCallRequested before execution. ToolCallCompleted is
      # emitted at the agent level after step monitoring.
      #
      # @see Events::ToolCallRequested
      # @see Events::ToolCallCompleted (emitted by agent monitoring)
      module Eventing
        include Events::Emitter

        private

        # Emits ToolCallRequested event before tool execution.
        #
        # @param args [Hash] Arguments being passed to the tool
        def emit_tool_call_requested(args)
          return unless emitting?

          emit(Events::ToolCallRequested.create(
                 tool_name: name,
                 args: args.freeze
               ))
        end
      end
    end
  end
end
