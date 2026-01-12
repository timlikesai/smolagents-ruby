module Smolagents
  module Agents
    class ToolCalling < Agent
      include Concerns::ToolExecution

      def initialize(tools:, model:, max_tool_threads: nil, **opts)
        super(tools: tools, model: model, **opts)
        @max_tool_threads = max_tool_threads || DEFAULT_MAX_TOOL_THREADS
      end
    end
  end
end
