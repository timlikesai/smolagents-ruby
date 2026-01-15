# Bidirectional control helpers for Fiber-based agent execution.
#
# Provides convenient methods for agents and tools to pause execution
# and request input from consumers (users, parent agents, orchestrators).
#
# @example Requesting user input in a tool
#   def execute(query:)
#     query = request_input("What would you like to search for?") if query.empty?
#     perform_search(query)
#   end
#
# @example Requesting confirmation before action
#   def execute(path:)
#     return "Aborted" unless request_confirmation(
#       action: "delete_file",
#       description: "Delete #{path}",
#       reversible: false
#     )
#     File.delete(path)
#   end
module Smolagents
  module Concerns
    module ReActLoop
      module Control
        # Request user input, pausing execution until response received.
        #
        # @param prompt [String] Question or prompt for the user
        # @param options [Array<String>, nil] Suggested response options
        # @param timeout [Integer, nil] Optional timeout in seconds
        # @param context [Hash] Additional context for the request
        # @return [String] User's response value
        # @raise [ControlFlowError] If not in a Fiber context
        def request_input(prompt, options: nil, timeout: nil, context: {})
          ensure_fiber_context!
          request = Types::ControlRequests::UserInput.create(prompt:, options:, timeout:, context:)
          response = yield_control(request)
          response.value
        end

        # Request confirmation before executing an action.
        #
        # @param action [String] Action identifier (e.g., "delete_file")
        # @param description [String] Human-readable description of the action
        # @param consequences [Array<String>] List of potential consequences
        # @param reversible [Boolean] Whether the action can be undone
        # @return [Boolean] True if action was approved, false otherwise
        # @raise [ControlFlowError] If not in a Fiber context
        def request_confirmation(action:, description:, consequences: [], reversible: true)
          ensure_fiber_context!
          request = Types::ControlRequests::Confirmation.create(
            action:, description:, consequences:, reversible:
          )
          response = yield_control(request)
          response.approved?
        end

        # Escalate a query to parent agent or user.
        #
        # Used by sub-agents when they need guidance or clarification
        # from their parent agent or the end user.
        #
        # @param query [String] Question to escalate
        # @param options [Array<String>, nil] Suggested response options
        # @param context [Hash] Additional context
        # @return [String] Response value from parent/user
        # @raise [ControlFlowError] If not in a Fiber context
        def escalate_query(query, options: nil, context: {})
          ensure_fiber_context!
          request = Types::ControlRequests::SubAgentQuery.create(
            agent_name: agent_name_for_escalation,
            query:, options:, context:
          )
          response = yield_control(request)
          response.value
        end

        private

        def ensure_fiber_context!
          return if fiber_context?

          raise Errors::ControlFlowError,
                "Control requests require Fiber context. Use run_fiber instead of run."
        end

        def agent_name_for_escalation
          self.class.name&.split("::")&.last&.downcase || "agent"
        end
      end
    end
  end
end
