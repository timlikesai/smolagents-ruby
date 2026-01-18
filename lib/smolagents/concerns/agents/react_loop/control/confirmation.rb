module Smolagents
  module Concerns
    module ReActLoop
      module Control
        # Confirmation dialogs for potentially dangerous actions.
        #
        # Enables agents to request user approval before executing
        # actions with side effects.
        #
        # @example Confirming file deletion
        #   if request_confirmation(action: "delete", description: "Delete config.yml")
        #     delete_file("config.yml")
        #   end
        module Confirmation
          # Documents methods provided by this concern.
          def self.provided_methods
            { request_confirmation: "Request user confirmation for an action" }
          end

          # Request confirmation for an action.
          #
          # Pauses execution and yields a Confirmation request.
          # Returns true if approved, false otherwise.
          #
          # @param action [String] Short action name (e.g., "delete_file")
          # @param description [String] Human-readable description of the action
          # @param consequences [Array<String>] List of potential consequences
          # @param reversible [Boolean] Whether the action can be undone
          # @return [Boolean] True if approved, false if denied
          # @raise [Errors::ControlFlowError] If not in Fiber context
          def request_confirmation(action:, description:, consequences: [], reversible: true) # rubocop:disable Naming/PredicateMethod
            ensure_fiber_context!
            request = Types::ControlRequests::Confirmation.create(
              action:, description:, consequences:, reversible:
            )
            yield_control(request).approved?
          end
        end
      end
    end
  end
end
