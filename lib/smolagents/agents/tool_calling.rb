module Smolagents
  module Agents
    class ToolCalling < Agent
      include Concerns::ToolExecution

      def initialize(tools:, model:, max_tool_threads: nil, **)
        super(tools: tools, model: model, **)
        @max_tool_threads = max_tool_threads || DEFAULT_MAX_TOOL_THREADS
      end
    end
  end
end
