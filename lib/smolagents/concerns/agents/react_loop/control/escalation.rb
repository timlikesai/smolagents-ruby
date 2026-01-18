module Smolagents
  module Concerns
    module ReActLoop
      module Control
        # Sub-agent escalation for delegation patterns.
        #
        # @example Escalating a complex query
        #   answer = escalate_query("What is the legal status?", context: { topic: "compliance" })
        module Escalation
          include RequestBase

          def self.provided_methods
            { escalate_query: "Escalate a query to parent/user" }
          end

          # Escalate a query to another agent or external handler.
          # @return [String, Object] Response from the handler
          def escalate_query(query, options: nil, context: {})
            yield_request(Types::ControlRequests::SubAgentQuery,
                          agent_name: agent_name_for_escalation, query:, options:, context:)
          end

          private

          def agent_name_for_escalation
            return "agent" unless (name = self.class.name)

            name.split("::").last.downcase
          end
        end
      end
    end
  end
end
