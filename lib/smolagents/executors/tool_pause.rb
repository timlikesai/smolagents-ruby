module Smolagents
  module Executors
    # Represents a pause point after a tool call during incremental execution.
    #
    # When code executes in a Fiber, each tool call yields a ToolPause back to
    # the executor. This allows the agent to observe results before continuing.
    #
    # @example Handling a pause in the executor
    #   pause = fiber.resume
    #   case pause
    #   when ToolPause
    #     if pause.retrieval_tool?
    #       # Force model to observe before final_answer
    #       return partial_result(pause)
    #     end
    #   end
    #
    # Tools that retrieve external data requiring observation before answering.
    RETRIEVAL_TOOL_NAMES = %w[
      wikipedia web_search duckduckgo_search search web fetch
      google_search bing_search http_request searxng
    ].freeze

    # @see IncrementalExecution For the Fiber-based execution loop
    ToolPause = Data.define(:tool_name, :arguments, :result, :duration) do
      # @return [Boolean] True if this tool retrieves external data
      def retrieval_tool?
        name_lower = tool_name.to_s.downcase
        Executors::RETRIEVAL_TOOL_NAMES.any? { |t| name_lower.include?(t) }
      end

      # @return [Boolean] True if this is the final_answer tool
      def final_answer? = tool_name.to_s == "final_answer"

      # @return [String] Human-readable representation
      def to_s = "ToolPause[#{tool_name}]"
    end
  end
end
