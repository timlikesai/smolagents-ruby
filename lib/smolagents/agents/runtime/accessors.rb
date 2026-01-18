module Smolagents
  module Agents
    class AgentRuntime
      # Accessor methods and attribute readers for AgentRuntime.
      #
      # Provides read access to runtime components and state.
      # Extracted to keep the main class focused.
      #
      # @api private
      module Accessors
        # @!attribute [r] executor
        #   The code executor for sandboxed Ruby execution.
        #   @return [Executors::Executor] The code executor (sandbox)
        #   @see Executors::LocalRuby Default executor
        #   @see Executors::Ractor Memory-isolated executor

        # @!attribute [r] authorized_imports
        #   List of Ruby libraries allowed for require statements in agent code.
        #   @return [Array<String>] Allowed Ruby libraries (e.g., ["json", "uri"])
        #   @example
        #     runtime.authorized_imports
        #     # => ["json", "uri", "date"]

        def self.included(base)
          base.attr_reader :executor, :authorized_imports, :sync_events
        end

        # Emits an event, using sync mode if configured.
        #
        # When sync_events is enabled, events are emitted synchronously
        # so handlers execute immediately. This is useful for IRB/interactive
        # contexts where async events may not fire before the REPL returns.
        #
        # @param event [Object] The event to emit
        # @return [Object] The event
        def emit_event(event)
          @sync_events ? emit_sync(event) : emit(event)
        end

        # Converts memory to LLM message format with context injection.
        #
        # Used internally by CodeExecution to prepare messages for the model.
        # Applies multiple context injections in order:
        # 1. Plan context (if planning enabled)
        # 2. Step context (budget, last tool outcome)
        #
        # @param summary_mode [Boolean] If true, uses condensed message format
        # @return [Array<Types::ChatMessage>] Messages suitable for LLM context
        # @api private
        def write_memory_to_messages(summary_mode: false)
          messages = @memory.to_messages(summary_mode:)
          messages = inject_plan_into_messages(messages)
          inject_context_into_messages(messages)
        end
      end
    end
  end
end
