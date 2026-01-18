module Smolagents
  module Concerns
    module ReActLoop
      module Control
        # User input requests during agent execution.
        #
        # Enables agents to pause and request text input from users.
        # Requires fiber context to function.
        #
        # @example Requesting clarification
        #   clarification = request_input("Which aspect interests you?")
        module UserInput
          # Documents methods provided by this concern.
          def self.provided_methods
            { request_input: "Request text input from user" }
          end

          # Request input from an external source.
          #
          # Pauses agent execution and yields a UserInput request.
          # The Fiber must be resumed with a Response containing the input.
          #
          # @param prompt [String] Question or prompt for the user
          # @param options [Array<String>, nil] Valid response options (if constrained)
          # @param timeout [Integer, nil] Timeout in seconds (informational)
          # @param context [Hash] Additional context for the request handler
          # @return [String, Object] The value from the Response
          # @raise [Errors::ControlFlowError] If not in Fiber context
          def request_input(prompt, options: nil, timeout: nil, context: {})
            ensure_fiber_context!
            response = yield_control(
              Types::ControlRequests::UserInput.create(prompt:, options:, timeout:, context:)
            )
            response.value
          end
        end
      end
    end
  end
end
