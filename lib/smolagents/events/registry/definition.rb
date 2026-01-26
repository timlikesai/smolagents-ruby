# Immutable event definition type with documentation support.
#
# Each registered event has a definition containing its name,
# description, parameters, and usage examples.
#
# @example Creating an event definition
#   defn = EventDefinition.new(
#     name: :step_complete,
#     description: "Fired after each step",
#     params: %i[step context],
#     param_descriptions: { step: "The step that completed" },
#     example: "agent.on(:step_complete) { |step, ctx| ... }",
#     category: :lifecycle
#   )
#   defn.signature  #=> "on(:step_complete) { |step, context| ... }"
#
module Smolagents
  module Events
    module Registry
      # Immutable event definition with documentation.
      EventDefinition = Data.define(
        :name, :description, :params, :param_descriptions, :example, :category
      ) do
        # Generates the callback signature for documentation.
        # @return [String] The callback signature
        def signature
          "on(:#{name}) { |#{params.join(", ")}| ... }"
        end

        # Converts to a hash for serialization.
        # @return [Hash]
        def to_h
          { name:, description:, params:, param_descriptions:, signature:, example:, category: }
        end

        # Pattern matching support.
        def deconstruct_keys(_) = to_h
      end
    end
  end
end
