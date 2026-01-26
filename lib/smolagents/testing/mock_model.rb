require "monitor"
require_relative "mock_call"
require_relative "mock_model/queue"
require_relative "mock_model/query"

module Smolagents
  module Testing
    # Deterministic model for testing agent behavior without LLM calls.
    #
    # Queue responses in order, run your agent, verify messages received.
    # Thread-safe via Monitor (re-entrant safe).
    #
    # @example Basic usage
    #   model = MockModel.new
    #   model.queue_final_answer("42")
    #   agent = Smolagents.agent.model { model }.build
    #   result = agent.run("question")
    #   expect(model.call_count).to eq(1)
    #
    # @see MockModelQueue Queue methods
    # @see MockModelQuery Query methods
    class MockModel < Models::Model
      include MockModelQueue
      include MockModelQuery

      # @return [Array<MockCall>] All generate() calls
      attr_reader :calls
      # @return [Integer] Number of generate() calls
      attr_reader :call_count

      # @param model_id [String] Model identifier
      def initialize(model_id: "mock-model")
        super
        @calls = []
        @call_count = 0
        @responses = []
        @monitor = Monitor.new
      end

      # Returns next queued response, recording the call.
      # @raise [RuntimeError] When no responses queued
      def generate(messages, tools_to_call_from: nil, **)
        @monitor.synchronize do
          @call_count += 1
          record_call(messages, tools_to_call_from)
          next_response
        end
      end

      # Clears all state. @return [self]
      def reset!
        @monitor.synchronize do
          @calls.clear
          @responses.clear
          @call_count = 0
        end
        self
      end

      # Fluent API aliases for method chaining
      alias returns queue_response
      alias returns_code queue_code_action
      alias answers queue_final_answer

      private

      def record_call(messages, tools_to_call_from)
        @calls << MockCall.new(
          index: @call_count,
          messages: messages.dup.freeze,
          tools_to_call_from: tools_to_call_from&.dup&.freeze,
          timestamp: Time.now
        )
      end

      def next_response
        raise no_responses_error if @responses.empty?

        @responses.shift
      end

      def no_responses_error
        <<~ERROR.gsub(/\s+/, " ").strip
          MockModel: No more queued responses (call ##{@call_count}).
          Queue responses with queue_response(), queue_code_action(),
          queue_final_answer(), or queue_tool_call() before running agent.
        ERROR
      end
    end
  end
end
