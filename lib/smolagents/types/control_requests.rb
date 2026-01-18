# Bidirectional control request types for Fiber-based agent execution.
#
# Control requests enable agents to pause execution and request input from
# consumers (users, parent agents, or orchestrators). The DSL mirrors the
# event system for consistency.
#
# @example Pattern matching on requests
#   case result
#   in ControlRequests::UserInput => req
#     response = prompt_user(req.prompt)
#     fiber.resume(ControlRequests::Response.respond(request_id: req.id, value: response))
#   end
#
# @example Using factory methods
#   ControlRequests.user_input(prompt: "Which file?", options: ["a", "b"])
#   ControlRequests.confirmation(action: "delete", description: "Delete file")
#
# @example Sync behavior handling
#   case request.sync_behavior
#   in SyncBehavior::RAISE then raise ControlFlowError
#   in SyncBehavior::DEFAULT then Response.respond(request_id: req.id, value: req.default_value)
#   in SyncBehavior::APPROVE then Response.approve(request_id: req.id)
#   in SyncBehavior::SKIP then Response.respond(request_id: req.id, value: nil)
#   end

require_relative "control_requests/sync_behavior"
require_relative "control_requests/request"
require_relative "control_requests/response"
require_relative "control_requests/dsl"
require_relative "control_requests/definitions"

module Smolagents
  module Types
    module ControlRequests
      extend DSL

      # Load all request type definitions
      DefinitionLoader.load(self)
    end
  end
end
