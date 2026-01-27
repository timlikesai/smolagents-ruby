# Agent call log for recording and querying execution history.

module Smolagents
  module Testing
    # Records agent execution history for testing assertions.
    #
    # CallLog subscribes to agent events and records tool calls, model
    # calls, and step execution for later inspection. Enables powerful
    # test assertions about agent behavior.
    #
    # @example Basic usage
    #   log = CallLog.new
    #   agent.connect_to(log)
    #   agent.run("task")
    #
    #   expect(log.tool_calls).to include(name: :search)
    #   expect(log.model_calls.count).to eq(3)
    #
    # @example Pattern matching
    #   log.include?(tool: :search, args: { query: /Ruby/ })
    #
    # @see CallLogEntry Individual log entry structure
    class CallLog
      include Events::Consumer

      # @return [Array<CallLogEntry>] All recorded entries
      attr_reader :entries

      def initialize
        @entries = []
        @mutex = Mutex.new
        setup_subscriptions
      end

      # Tool call entries.
      # @return [Array<CallLogEntry>]
      def tool_calls = filter_by_type(:tool_call)

      # Model call entries.
      # @return [Array<CallLogEntry>]
      def model_calls = filter_by_type(:model_call)

      # Step completion entries.
      # @return [Array<CallLogEntry>]
      def steps = filter_by_type(:step)

      # Total count of all entries.
      # @return [Integer]
      def count = @mutex.synchronize { @entries.size }

      # Checks if any entry matches the pattern.
      #
      # @param pattern [Hash] Pattern to match against entries
      # @return [Boolean]
      #
      # @example Match tool by name
      #   log.include?(tool: :search)
      #
      # @example Match tool with arguments
      #   log.include?(tool: :search, args: { query: "Ruby" })
      #
      # @example Match with regex
      #   log.include?(tool: :search, args: { query: /Ruby|Python/ })
      def include?(pattern)
        @mutex.synchronize { @entries.any? { |e| e.matches?(pattern) } }
      end

      # Finds all entries matching the pattern.
      #
      # @param pattern [Hash] Pattern to match
      # @return [Array<CallLogEntry>]
      def select(pattern)
        @mutex.synchronize { @entries.select { |e| e.matches?(pattern) } }
      end

      # Returns the last entry matching the pattern.
      #
      # @param pattern [Hash, nil] Optional pattern to filter
      # @return [CallLogEntry, nil]
      def last(pattern = nil)
        @mutex.synchronize do
          return @entries.last unless pattern

          @entries.reverse.find { |e| e.matches?(pattern) }
        end
      end

      # Clears all recorded entries.
      # @return [self]
      def clear!
        @mutex.synchronize { @entries.clear }
        self
      end

      # Returns entries as array of hashes for easy comparison.
      # @return [Array<Hash>]
      def to_a = @mutex.synchronize { @entries.map(&:to_h) }

      # Processes an incoming event and records it.
      # @param event [Event] Event to process
      # @return [void]
      def consume(event)
        entry = CallLogEntry.from_event(event)
        return unless entry

        @mutex.synchronize { @entries << entry }
      end

      private

      def setup_subscriptions
        on_tools { |e| consume(e) }
        on_models { |e| consume(e) }
        on_lifecycle { |e| consume(e) }
      end

      def filter_by_type(type)
        @mutex.synchronize { @entries.select { |e| e.type == type } }
      end
    end

    # Immutable record of a single call log entry.
    #
    # @example Creating an entry
    #   entry = CallLogEntry.new(
    #     type: :tool_call,
    #     name: :search,
    #     args: { query: "Ruby" },
    #     result: "Found 10 results",
    #     timestamp: Time.now
    #   )
    #
    # @example Pattern matching
    #   entry.matches?(tool: :search, args: { query: /Ruby/ })
    CallLogEntry = Data.define(:type, :name, :args, :result, :timestamp, :metadata) do
      # Creates a CallLogEntry from an event.
      #
      # @param event [Event] Event to convert
      # @return [CallLogEntry, nil] Entry or nil if event type not supported
      def self.from_event(event)
        case event
        when Events::ToolCallCompleted then from_tool_event(event)
        when Events::ModelGenerateCompleted then from_model_event(event)
        when Events::StepCompleted then from_step_event(event)
        end
      end

      def self.from_tool_event(event)
        new(type: :tool_call, name: event.tool_name.to_sym, args: {},
            result: event.result, timestamp: event.created_at,
            metadata: { observation: event.observation, is_final: event.is_final })
      end

      def self.from_model_event(event)
        new(type: :model_call, name: event.model_id.to_sym, args: {},
            result: nil, timestamp: event.created_at,
            metadata: { duration_ms: event.duration_ms, token_usage: event.token_usage })
      end

      def self.from_step_event(event)
        new(type: :step, name: :"step#{event.step_number}",
            args: { step_number: event.step_number },
            result: event.observations, timestamp: event.created_at,
            metadata: { outcome: event.outcome })
      end

      # Checks if this entry matches the given pattern.
      #
      # @param pattern [Hash] Pattern to match
      # @return [Boolean]
      #
      # @example Simple match
      #   entry.matches?(tool: :search)
      #
      # @example Match with args
      #   entry.matches?(tool: :search, args: { query: "test" })
      def matches?(pattern)
        return match_tool?(pattern) if pattern.key?(:tool)
        return match_model?(pattern) if pattern.key?(:model)
        return match_step?(pattern) if pattern.key?(:step)

        pattern.all? { |k, v| match_value?(send(k), v) }
      end

      # Whether this is a tool call entry.
      # @return [Boolean]
      def tool_call? = type == :tool_call

      # Whether this is a model call entry.
      # @return [Boolean]
      def model_call? = type == :model_call

      # Whether this is a step entry.
      # @return [Boolean]
      def step? = type == :step

      private

      def match_tool?(pattern)
        return false unless tool_call?
        return false unless match_value?(name, pattern[:tool])
        return true unless pattern[:args]

        match_args?(pattern[:args])
      end

      def match_model?(pattern)
        return false unless model_call?

        match_value?(name, pattern[:model])
      end

      def match_step?(pattern)
        return false unless step?

        step_num = pattern[:step]
        return true if step_num.nil?

        args[:step_number] == step_num
      end

      def match_args?(expected_args)
        expected_args.all? { |k, v| match_value?(args[k], v) }
      end

      def match_value?(actual, expected)
        case expected
        when Regexp then actual.to_s.match?(expected)
        when Symbol then actual.to_sym == expected
        else actual == expected
        end
      end
    end
  end
end
