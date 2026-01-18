module Smolagents
  module Concerns
    module ReActLoop
      module Control
        # Sub-agent escalation for delegation patterns.
        #
        # Enables agents to escalate queries to parent agents,
        # expert systems, or external handlers.
        #
        # @example Escalating a complex query
        #   answer = escalate_query("What is the legal status?", context: { topic: "compliance" })
        module Escalation
          # Documents methods provided by this concern.
          def self.provided_methods
            { escalate_query: "Escalate a query to parent/user" }
          end

          # Escalate a query to another agent or external handler.
          #
          # Used for delegation patterns where one agent needs to consult
          # another agent or expert system.
          #
          # @param query [String] The query to escalate
          # @param options [Hash, nil] Additional options for the handler
          # @param context [Hash] Context about the escalation
          # @return [String, Object] Response from the handler
          # @raise [Errors::ControlFlowError] If not in Fiber context
          def escalate_query(query, options: nil, context: {})
            ensure_fiber_context!
            request = Types::ControlRequests::SubAgentQuery.create(
              agent_name: agent_name_for_escalation,
              query:, options:, context:
            )
            yield_control(request).value
          end

          private

          def agent_name_for_escalation
            class_name = self.class.name
            class_name ? class_name.split("::").last.downcase : "agent"
          end
        end
      end
    end
  end
end
