module Smolagents
  module Executors
    module FiberExecution
      # Tools that retrieve external data - orchestrator should observe before continuing
      RETRIEVAL_TOOLS = %w[
        search web fetch wikipedia http api query
        duckduckgo google bing searxng
      ].freeze

      # What gets yielded when a tool is called.
      #
      # Contains everything the orchestrator needs to decide what to do next.
      ToolYield = Data.define(:tool_name, :arguments, :result, :duration) do
        # @return [Boolean] True if tool retrieves external data
        def retrieval? = FiberExecution::RETRIEVAL_TOOLS.any? { |t| tool_name.to_s.downcase.include?(t) }

        # @return [Boolean] True if this completes the task
        def final? = tool_name.to_s == "final_answer"

        # @return [Boolean] True if this is a subagent call
        def subagent? = tool_name.to_s.start_with?("agent_") || result.is_a?(RunResult)
      end

      # Execution state after a batch yield or completion.
      ExecutionState = Data.define(:status, :batches, :batch, :output, :error) do
        def self.running(batches, current_batch)
          new(status: :running, batches:, batch: current_batch, output: nil, error: nil)
        end

        def self.completed(output, batches) = new(status: :completed, batches:, batch: nil, output:, error: nil)
        def self.failed(error, batches) = new(status: :failed, batches:, batch: nil, output: nil, error:)

        def running? = status == :running
        def completed? = status == :completed
        def failed? = status == :failed

        # All futures from all batches
        def all_futures = batches.flat_map(&:futures)

        # Current batch has retrieval tools?
        def retrieval_batch? = batch&.futures&.any? { |f| retrieval_tool?(f.tool_name) }

        # Current batch has final_answer?
        def final_answer_batch? = batch&.futures&.any? { |f| f.tool_name == "final_answer" }

        private

        def retrieval_tool?(name) = FiberExecution::RETRIEVAL_TOOLS.any? { |t| name.to_s.downcase.include?(t) }
      end
    end
  end
end
