module Smolagents
  module Types
    module TypeSupport
      # Generates predicate methods from state mapping.
      #
      # Many Data.define types have a :state or :status field with predicate
      # methods like success?, error?, etc. This module generates them from
      # a simple mapping declaration.
      #
      # @example Basic usage
      #   RunResult = Data.define(:state, :output) do
      #     include TypeSupport::StatePredicates
      #     state_predicates success: :success,
      #                      error: :error,
      #                      timeout: :timeout
      #   end
      #
      #   result = RunResult.new(state: :success, output: "done")
      #   result.success?  # => true
      #   result.error?    # => false
      #
      # @example Custom state field
      #   EvaluationResult = Data.define(:status, :answer) do
      #     include TypeSupport::StatePredicates
      #     state_predicates :status,
      #                      achieved: :goal_achieved,
      #                      stuck: :stuck,
      #                      continue: :continue
      #   end
      #
      # @example Group predicates with arrays
      #   RunResult = Data.define(:state, :output) do
      #     include TypeSupport::StatePredicates
      #     state_predicates terminal: [:success, :error, :timeout],
      #                      retriable: [:partial, :max_steps]
      #   end
      #
      module StatePredicates
        # Hook called when module is included.
        #
        # @param base [Class] The Data.define class including this module
        def self.included(base)
          base.extend(ClassMethods)
        end

        # Class-level DSL for defining state predicates.
        module ClassMethods
          # Defines predicate methods for state checking.
          #
          # @param field_or_mapping [Symbol, Hash] Either the state field name (if not :state)
          #   or the first predicate mapping
          # @param mappings [Hash{Symbol => Symbol, Array<Symbol>}] Predicate name to state value(s)
          # @return [void]
          #
          # @example Default :state field
          #   state_predicates success: :success, error: :error
          #
          # @example Custom field name
          #   state_predicates :status, achieved: :goal_achieved
          #
          # @example Group predicate
          #   state_predicates failed: [:error, :timeout]
          def state_predicates(field_or_mapping = nil, **mappings)
            field, mappings = parse_predicates_args(field_or_mapping, mappings)
            mappings.each { |name, values| define_predicate(field, name, values) }
          end

          private

          def parse_predicates_args(first_arg, mappings)
            return [:state, mappings] if first_arg.nil?
            return [:state, first_arg.merge(mappings)] if first_arg.is_a?(Hash)
            return [first_arg, mappings] if members.include?(first_arg)

            [:state, { first_arg => mappings.values.first }.merge(mappings)]
          end

          def define_predicate(field, name, values)
            method_name = "#{name}?"

            if values.is_a?(Array)
              define_method(method_name) { values.include?(public_send(field)) }
            else
              define_method(method_name) { public_send(field) == values }
            end
          end
        end
      end
    end
  end
end
