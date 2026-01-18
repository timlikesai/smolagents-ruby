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
        def self.approve(request_id:, value: nil) = new(request_id:, value:, approved: true)
        def self.deny(request_id:, reason: nil) = new(request_id:, value: reason, approved: false)
        def self.respond(request_id:, value:) = new(request_id:, value:, approved: true)

        def approved? = approved
        def denied? = !approved
      end
    end
  end
end
