# Bidirectional control request types for Fiber-based agent execution.
#
# Control requests enable agents to pause execution and request input from
# consumers (users, parent agents, or orchestrators). The DSL mirrors the
# event system for consistency.
#
# @example Defining a custom request type
#   define_request :CustomInput, fields: %i[prompt data], defaults: { data: {} }
#
# @example Defining with predicates
#   define_request :UserInput,
#                  fields: %i[prompt options],
#                  predicates: { has_options: ->(r) { r.options&.any? } }
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
module Smolagents
  module Types
    module ControlRequests
      # Sync behavior constants for control requests in sync mode.
      #
      # Determines how control requests are handled when using run() instead of run_fiber().
      module SyncBehavior
        RAISE = :raise      # Raise ControlFlowError (current behavior)
        DEFAULT = :default  # Use default value if available
        APPROVE = :approve  # Auto-approve confirmations
        SKIP = :skip        # Skip and return nil
      end

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

      # DSL for defining control request types (mirrors Events::DSL).
      module DSL
        # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        def define_request(name, fields:, defaults: {}, freeze: [], predicates: {})
          all_fields = [:id] + fields + [:created_at]

          request_class = Data.define(*all_fields) do
            include Request

            define_singleton_method(:create) do |**kwargs|
              defaults.each { |k, v| kwargs[k] = v unless kwargs.key?(k) }
              freeze.each { |f| kwargs[f] = kwargs[f]&.freeze }
              new(id: SecureRandom.uuid, created_at: Time.now, **kwargs)
            end

            # Generate predicate methods from lambdas
            predicates.each do |method_name, predicate_lambda|
              define_method(:"#{method_name}?") { predicate_lambda.call(self) }
            end
          end

          const_set(name, request_class)

          # Generate factory method on the module
          factory_name = name.to_s.gsub(/([a-z])([A-Z])/, '\1_\2').downcase.to_sym
          define_singleton_method(factory_name) do |**kwargs|
            const_get(name).create(**kwargs)
          end
        end
        # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
      end

      extend DSL

      # Request for user input during agent execution.
      #
      # Agents yield this when clarification or additional information is needed.
      # Consumer should resume the fiber with a Response containing user's answer.
      # In sync mode, uses default_value if available (:default behavior).
      #
      # @example Agent requesting input
      #   request = UserInput.create(prompt: "Which file?", options: ["a.rb", "b.rb"])
      #   request.has_options?  # => true
      #
      # @example With default for sync mode
      #   request = UserInput.create(prompt: "Format?", default_value: "json")
      define_request :UserInput,
                     fields: %i[prompt context options timeout default_value sync_behavior],
                     defaults: { context: {}, options: nil, timeout: nil, default_value: nil,
                                 sync_behavior: SyncBehavior::DEFAULT },
                     freeze: %i[context options],
                     predicates: { has_options: ->(r) { r.options&.any? || false } }

      # Request from sub-agent to parent for guidance.
      #
      # Sub-agents yield this when encountering situations requiring escalation.
      # Parent agents can respond directly or bubble up to user.
      # In sync mode, skips and returns nil (:skip behavior).
      #
      # @example Sub-agent escalating
      #   request = SubAgentQuery.create(
      #     agent_name: "researcher",
      #     query: "Include results older than 2024?",
      #     options: ["yes", "no"]
      #   )
      #   request.has_options?  # => true
      define_request :SubAgentQuery,
                     fields: %i[agent_name query context options sync_behavior],
                     defaults: { context: {}, options: nil, sync_behavior: SyncBehavior::SKIP },
                     freeze: %i[context options],
                     predicates: { has_options: ->(r) { r.options&.any? || false } }

      # Request to confirm a potentially dangerous action.
      #
      # Agents yield this before executing actions with side effects.
      # Consumer must approve or deny via Response.
      # In sync mode: auto-approves if reversible, raises if not.
      #
      # @example Confirming file deletion
      #   request = Confirmation.create(
      #     action: "delete_file",
      #     description: "Delete /tmp/old.json",
      #     consequences: ["Data lost permanently"],
      #     reversible: false
      #   )
      #   request.dangerous?  # => true (not reversible)
      define_request :Confirmation,
                     fields: %i[action description consequences reversible sync_behavior],
                     defaults: { consequences: [], reversible: true, sync_behavior: nil },
                     freeze: [:consequences],
                     predicates: { dangerous: ->(r) { !r.reversible } }

      # Override Confirmation to compute sync_behavior based on reversibility.
      class << Confirmation
        alias _original_create create

        def create(**kwargs)
          kwargs[:sync_behavior] ||= kwargs.fetch(:reversible, true) ? SyncBehavior::APPROVE : SyncBehavior::RAISE
          _original_create(**kwargs)
        end
      end

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
