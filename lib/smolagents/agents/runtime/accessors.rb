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
          base.attr_reader :executor, :authorized_imports
        end

        # Converts memory to LLM message format with plan injection.
        #
        # Used internally by CodeExecution to prepare messages for the model.
        # Delegates to AgentMemory#to_messages, then injects plan context if enabled.
        #
        # @param summary_mode [Boolean] If true, uses condensed message format
        # @return [Array<Types::ChatMessage>] Messages suitable for LLM context
        # @api private
        def write_memory_to_messages(summary_mode: false)
          messages = @memory.to_messages(summary_mode:)
          inject_plan_into_messages(messages)
        end

        # Fallback for when Planning concern is not included.
        def inject_plan_into_messages(messages) = messages
      end
    end
  end
end
