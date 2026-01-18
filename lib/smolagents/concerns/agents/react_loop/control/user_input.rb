module Smolagents
  module Concerns
    module ReActLoop
      module Control
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
      end
    end
  end
end
