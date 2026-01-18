# Child agent's interface to parent context and communication.
#
# Environment provides child agents with:
# - Read-only access to parent-supplied context
# - Capability checks for permission control
# - Fiber-based communication with parent agents
#
# @example Standalone agent (no parent)
#   env = Environment.standalone(context: { task: "research" })
#   env[:task]  # => "research"
#   env.ask("question")  # raises EnvironmentError
#
# @example Child agent with parent communication
#   env = Environment.for_child(
#     context: { agent_name: "researcher", scope: "web" },
#     capabilities: [:search, :summarize],
#     parent_fiber: parent_fiber
#   )
#   env.can?(:search)     # => true
#   env.ask("clarify?")   # => yields SubAgentQuery to parent
#
# @example Capability-gated operations
#   raise "Not allowed" unless env.can?(:file_write)
#   perform_write(data)
module Smolagents
  module Runtime
    Environment = Data.define(:context, :capabilities, :parent_fiber) do
      # Creates a standalone environment with no parent.
      #
      # @param context [Hash] read-only context data
      # @return [Environment] standalone environment
      def self.standalone(context: {})
        new(context: context.freeze, capabilities: Set.new, parent_fiber: nil)
      end

      # Creates an environment for a child agent.
      #
      # @param context [Hash] read-only context from parent
      # @param capabilities [Array<Symbol>] allowed capabilities
      # @param parent_fiber [Fiber, nil] fiber for parent communication
      # @return [Environment] child environment
      def self.for_child(context:, capabilities: [], parent_fiber: nil)
        new(
          context: context.freeze,
          capabilities: Set.new(Array(capabilities)),
          parent_fiber:
        )
      end

      # Checks if environment has a capability.
      #
      # @param capability [Symbol, String] capability to check
      # @return [Boolean] true if capability is present
      def can?(capability) = capabilities.include?(capability.to_sym)

      # Asks the parent agent a question via fiber communication.
      #
      # @param question [String] question to ask parent
      # @param options [Array, nil] optional answer choices
      # @return [Object] parent's response value
      # @raise [EnvironmentError] if no parent fiber available
      def ask(question, options: nil)
        raise Errors::EnvironmentError, "Cannot ask: no parent fiber" unless parent_fiber

        request = Types::ControlRequests::SubAgentQuery.create(
          agent_name: context[:agent_name] || "child",
          query: question,
          options:
        )

        response = Fiber.yield(request)
        response&.value
      end

      # Accesses context value by key.
      #
      # @param key [Symbol, String] context key
      # @param default [Object] default value if key not found
      # @return [Object] context value or default
      def [](key, default: nil) = context.fetch(key, default)

      # Checks if context contains a key.
      #
      # @param key [Symbol, String] context key
      # @return [Boolean] true if key exists
      def has?(key) = context.key?(key)
    end
  end

  Environment = Runtime::Environment
end
