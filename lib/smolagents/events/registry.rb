# Self-documenting event registry for runtime introspection.
#
# @example List all events
#   Smolagents::Events::Registry.all  #=> [:step_complete, :tool_complete, ...]
#
# @example Get event definition
#   defn = Smolagents::Events::Registry[:step_complete]
#   defn.signature  #=> "on(:step_complete) { |step, context| ... }"
#
require_relative "registry/definition"

module Smolagents
  module Events
    module Registry
      # rubocop:disable Style/MutableConstant -- intentionally mutable for runtime registration
      EVENTS = {}
      # rubocop:enable Style/MutableConstant

      class << self
        # @param name [Symbol] The event name
        # @param description [String] What the event represents
        # @param params [Array<Symbol>] Callback parameters
        # @param param_descriptions [Hash] Parameter descriptions
        # @param example [String, nil] Usage example
        # @param category [Symbol] Event category for grouping
        # @return [EventDefinition]
        def register(name, description:, params:, param_descriptions: {}, example: nil, category: :general)
          EVENTS[name] = EventDefinition.new(
            name:, description:, params:, param_descriptions:, example:, category:
          )
        end

        # @param name [Symbol] The event name
        # @return [EventDefinition, nil]
        def [](name) = EVENTS[name]

        # @return [Array<Symbol>]
        def all = EVENTS.keys

        # @return [Array<EventDefinition>]
        def definitions = EVENTS.values

        # @param name [Symbol] The event name
        # @return [Boolean]
        def registered?(name) = EVENTS.key?(name)

        # @param category [Symbol] The category to filter by
        # @return [Array<Symbol>]
        def by_category(category)
          EVENTS.select { |_, defn| defn.category == category }.keys
        end

        # @return [Array<Symbol>]
        def categories = EVENTS.values.map(&:category).uniq.sort

        # @return [String]
        def documentation
          EVENTS.values.group_by(&:category).map do |category, events|
            "# #{category.to_s.capitalize} Events\n\n" +
              events.map { |e| event_documentation(e) }.join("\n---\n\n")
          end.join("\n\n")
        end

        # @param builder_type [Symbol] :agent, :team, or :model
        # @return [Array<Symbol>]
        def for_builder(builder_type)
          case builder_type
          when :agent
            %i[step_complete tool_complete error control_yielded evaluation_complete
               refinement_complete goal_drift repetition_detected]
          when :team then %i[agent_launch agent_progress agent_complete error]
          when :model then %i[retry failover recovery error rate_limit]
          else all
          end
        end

        # @api private
        def clear! = EVENTS.clear

        private

        def event_documentation(event)
          params = event.params.map { |p| "  - #{p}: #{event.param_descriptions[p] || "No description"}" }
          doc = "## #{event.name}\n#{event.description}\n\n" \
                "Signature: `#{event.signature}`\n\nParameters:\n#{params.join("\n")}"
          event.example ? "#{doc}\n\nExample:\n```ruby\n#{event.example}\n```\n" : doc
        end
      end
    end
  end
end

require_relative "registry/built_in"
