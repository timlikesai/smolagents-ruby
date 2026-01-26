module Smolagents
  module Concerns
    module ReActLoop
      module Control
        # Base module for control flow requests.
        #
        # Provides the common pattern for yielding control requests:
        # 1. Ensure fiber context
        # 2. Create typed request
        # 3. Yield and get response
        # 4. Extract result value
        module RequestBase
          private

          # Yield a control request and extract the response.
          #
          # @param request_class [Class] The request type class
          # @param extractor [Proc, nil] How to extract result from response (default: &:value)
          # @param kwargs [Hash] Arguments for request creation
          # @yield [response] Optional block to extract result from response
          # @return [Object] Extracted result from response
          def yield_request(request_class, extractor: nil, **, &)
            ensure_fiber_context!
            request = request_class.create(**)
            response = yield_control(request)
            extract_response(response, extractor, &)
          end

          def extract_response(response, extractor, &block)
            return yield(response) if block
            return extractor.call(response) if extractor

            response.value
          end
        end

        # User input requests during agent execution.
        #
        # @example Requesting clarification
        #   clarification = request_input("Which aspect interests you?")
        module UserInput
          include RequestBase

          def self.provided_methods
            { request_input: "Request text input from user" }
          end

          # Request input from an external source.
          # @return [String, Object] The value from the Response
          def request_input(prompt, options: nil, timeout: nil, context: {})
            yield_request(Types::ControlRequests::UserInput, prompt:, options:, timeout:, context:)
          end
        end

        # Confirmation dialogs for potentially dangerous actions.
        #
        # @example Confirming file deletion
        #   if request_confirmation(action: "delete", description: "Delete config.yml")
        #     delete_file("config.yml")
        #   end
        module Confirmation
          include RequestBase

          def self.provided_methods
            { request_confirmation: "Request user confirmation for an action" }
          end

          # Request confirmation for an action.
          # @return [Boolean] True if approved, false if denied # -- returns approval status, not predicate
          def request_confirmation(action:, description:, consequences: [], reversible: true)
            yield_request(Types::ControlRequests::Confirmation,
                          action:, description:, consequences:, reversible:, &:approved?)
          end
        end

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
