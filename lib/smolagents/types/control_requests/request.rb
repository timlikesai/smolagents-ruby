module Smolagents
  module Types
    module ControlRequests
      # Base module included in all request types for pattern matching.
      module Request
        def request? = true
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
