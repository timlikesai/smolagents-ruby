module Smolagents
  module Concerns
    module ReActLoop
      module Control
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
      end
    end
  end
end
