module Smolagents
  module Types
    module ControlRequests
      # Base module included in all request types for pattern matching.
      module Request
        # Identifies this as a control request.
        #
        # @return [Boolean] Always true for control requests
        def request? = true

        # Converts request to hash for serialization.
        #
        # @return [Hash] Request fields as a hash
        def to_h = deconstruct_keys(nil)

        # Returns the request type as a symbol.
        #
        # @return [Symbol] the underscored type name
        # @example
        #   UserInput.create(prompt: "?").request_type  # => :user_input
        #   SubAgentQuery.create(...).request_type      # => :sub_agent_query
        def request_type
          self.class.name.split("::").last.gsub(/([a-z])([A-Z])/, '\1_\2').downcase.to_sym
        end
      end
    end
  end
end
