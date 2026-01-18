module Smolagents
  module Types
    module ControlRequests
      # Hash-driven request type definitions.
      #
      # Each entry defines a request type with its fields, defaults, freeze behavior,
      # and predicates. The DSL generates Data.define classes and factory methods.
      #
      # @return [Hash{Symbol => Hash}] Request type definitions with fields, defaults, freeze list, and predicates
      REQUEST_DEFINITIONS = {
        UserInput: {
          fields: %i[prompt context options timeout default_value sync_behavior],
          defaults: {
            context: {},
            options: nil,
            timeout: nil,
            default_value: nil,
            sync_behavior: SyncBehavior::DEFAULT
          },
          freeze: %i[context options],
          predicates: { has_options: ->(r) { r.options&.any? || false } },
          doc: <<~DOC
            Request for user input during agent execution.

            Agents yield this when clarification or additional information is needed.
            Consumer should resume the fiber with a Response containing user's answer.
            In sync mode, uses default_value if available (:default behavior).
          DOC
        },

        SubAgentQuery: {
          fields: %i[agent_name query context options sync_behavior],
          defaults: {
            context: {},
            options: nil,
            sync_behavior: SyncBehavior::SKIP
          },
          freeze: %i[context options],
          predicates: { has_options: ->(r) { r.options&.any? || false } },
          doc: <<~DOC
            Request from sub-agent to parent for guidance.

            Sub-agents yield this when encountering situations requiring escalation.
            Parent agents can respond directly or bubble up to user.
            In sync mode, skips and returns nil (:skip behavior).
          DOC
        },

        Confirmation: {
          fields: %i[action description consequences reversible sync_behavior],
          defaults: {
            consequences: [],
            reversible: true,
            sync_behavior: nil
          },
          freeze: [:consequences],
          predicates: { dangerous: ->(r) { !r.reversible } },
          doc: <<~DOC
            Request to confirm a potentially dangerous action.

            Agents yield this before executing actions with side effects.
            Consumer must approve or deny via Response.
            In sync mode: auto-approves if reversible, raises if not.
          DOC
        }
      }.freeze

      # Generates all request types from definitions.
      module DefinitionLoader
        # Generates all request type classes from REQUEST_DEFINITIONS.
        #
        # @param target [Module] Module to define request classes in
        # @return [void]
        def self.load(target)
          REQUEST_DEFINITIONS.each do |name, config|
            target.define_request(
              name,
              fields: config[:fields],
              defaults: config[:defaults],
              freeze: config[:freeze],
              predicates: config[:predicates]
            )
          end
          apply_confirmation_override(target)
        end

        # Overrides Confirmation.create to compute sync_behavior based on reversibility.
        #
        # @param target [Module] Module containing Confirmation class
        # @return [void]
        def self.apply_confirmation_override(target)
          confirmation = target.const_get(:Confirmation)
          confirmation.define_singleton_method(:_original_create, confirmation.method(:create))

          confirmation.define_singleton_method(:create) do |**kwargs|
            kwargs[:sync_behavior] ||= kwargs.fetch(:reversible, true) ? SyncBehavior::APPROVE : SyncBehavior::RAISE
            _original_create(**kwargs)
          end
        end
      end
    end
  end
end
