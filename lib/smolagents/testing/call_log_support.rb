# Call log support concern for agents.

module Smolagents
  module Testing
    # Adds call_log support to agents.
    #
    # Include this concern in an agent class to enable automatic
    # recording of execution history for test assertions.
    #
    # @example Manual inclusion
    #   agent.extend(Smolagents::Testing::CallLogSupport)
    #   agent.enable_call_log
    #   agent.run("task")
    #   agent.call_log.include?(tool: :search)
    #
    # @example Via test mode
    #   Smolagents.test_mode!
    #   agent = Smolagents.agent.model { mock }.build
    #   # call_log is automatically enabled
    #
    # @see CallLog For the call log implementation
    module CallLogSupport
      # Returns the call log for this agent.
      #
      # @return [CallLog, nil] The call log or nil if not enabled
      def call_log = @call_log

      # Enables call logging for this agent.
      #
      # Creates a new CallLog and connects it to receive events
      # from this agent. Call logs record tool calls, model calls,
      # and step execution.
      #
      # @return [CallLog] The newly created call log
      def enable_call_log
        @enable_call_log ||= begin
          log = CallLog.new
          connect_to_call_log(log)
          log
        end
      end

      # Disables call logging and clears the log.
      #
      # @return [self]
      def disable_call_log
        @call_log = nil
        self
      end

      # Checks if call logging is enabled.
      #
      # @return [Boolean]
      def call_log_enabled? = !@call_log.nil?

      private

      def connect_to_call_log(log)
        handler = ->(e) { log.consume(e) }

        # Tool events
        on(:tool_call, &handler)
        on(:tool_complete, &handler)

        # Model events
        on(:model_generate_requested, &handler)
        on(:model_generate_completed, &handler)

        # Lifecycle events
        on(:step_complete, &handler)
        on(:task_complete, &handler)
      end
    end
  end
end
