module Smolagents
  module Agents
    class ToolCalling < Base
      include Concerns::ToolExecution

      template File.join(__dir__, "../prompts/toolcalling_agent.yaml")

      def initialize(tools:, model:, max_tool_threads: nil, **opts)
        super
        @max_tool_threads = max_tool_threads || DEFAULT_MAX_TOOL_THREADS
      end

      private

      def execute_step(action_step)
        execute_tool_calling_step(action_step)
      end
    end
  end
end
