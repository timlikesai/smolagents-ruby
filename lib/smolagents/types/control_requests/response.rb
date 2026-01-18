module Smolagents
  module Types
    module ControlRequests
      # Response to a control request.
      #
      # Wraps the response value with metadata about the original request.
      # Use factory methods for common patterns.
      #
      # @example Approving a confirmation
      #   Response.approve(request_id: req.id)
      #
      # @example Responding with user input
      #   Response.respond(request_id: req.id, value: "config.yml")
      #
      # @example Denying an action
      #   Response.deny(request_id: req.id, reason: "User declined")
      Response = Data.define(:request_id, :value, :approved) do
        # Creates an approval response.
        #
        # @param request_id [String] ID of the request being responded to
        # @param value [Object, nil] Optional value (unused for approvals)
        # @return [Response] Approval response
        def self.approve(request_id:, value: nil) = new(request_id:, value:, approved: true)

        # Creates a denial response.
        #
        # @param request_id [String] ID of the request being responded to
        # @param reason [String, nil] Optional reason for denial
        # @return [Response] Denial response
        def self.deny(request_id:, reason: nil) = new(request_id:, value: reason, approved: false)

        # Creates a response with a value.
        #
        # @param request_id [String] ID of the request being responded to
        # @param value [Object] Response value
        # @return [Response] Approval response with value
        def self.respond(request_id:, value:) = new(request_id:, value:, approved: true)

        # Checks if response is an approval.
        #
        # @return [Boolean] True if approved
        def approved? = approved

        # Checks if response is a denial.
        #
        # @return [Boolean] True if not approved
        def denied? = !approved
      end
    end
  end
end
