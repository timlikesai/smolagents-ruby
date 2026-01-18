# TypeSupport modules for eliminating repetitive patterns in Data.define types.
#
# These modules provide reusable behaviors for immutable data types:
#
# - **Deconstructable**: Auto-generates deconstruct_keys for pattern matching
# - **Serializable**: Auto-generates to_h with calculated field support
# - **StatePredicates**: Generates predicate methods from state mappings
# - **FactoryBuilder**: DSL for defining factory class methods
#
# @example Combining all modules
#   RunResult = Data.define(:state, :output, :steps, :timing) do
#     include TypeSupport::Deconstructable
#     include TypeSupport::Serializable
#     include TypeSupport::StatePredicates
#     extend TypeSupport::FactoryBuilder
#
#     calculated_field :step_count, -> { steps.size }
#
#     state_predicates success: :success,
#                      error: :error,
#                      terminal: [:success, :error, :timeout]
#
#     factory :success, state: :success
#     factory :error, state: :error, output: nil
#   end
#
#   # Pattern matching
#   case result
#   in RunResult[state: :success, output:]
#     handle_success(output)
#   end
#
#   # Predicates
#   result.success?   # => true
#   result.terminal?  # => true
#
#   # Serialization
#   result.to_h       # includes :step_count
#
#   # Factories
#   RunResult.success(output: "done", steps: [], timing: nil)
#
# @see TypeSupport::Deconstructable
# @see TypeSupport::Serializable
# @see TypeSupport::StatePredicates
# @see TypeSupport::FactoryBuilder
module Smolagents
  module Types
    module TypeSupport
    end
  end
end

require_relative "support/deconstructable"
require_relative "support/serializable"
require_relative "support/state_predicates"
require_relative "support/factory_builder"
