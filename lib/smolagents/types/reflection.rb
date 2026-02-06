module Smolagents
  module Types
    # Configuration for reflection memory.
    #
    # @!attribute [r] max_reflections
    #   @return [Integer] Maximum reflections to store (default: 10)
    # @!attribute [r] enabled
    #   @return [Boolean] Whether reflection is enabled
    # @!attribute [r] include_successful
    #   @return [Boolean] Whether to store reflections on success too
    ReflectionConfig = Data.define(:max_reflections, :enabled, :include_successful) do
      extend TypeSupport::FactoryBuilder

      DEFAULT_MAX_REFLECTIONS = 10

      factory :default,  max_reflections: DEFAULT_MAX_REFLECTIONS, enabled: true, include_successful: false
      factory :disabled, max_reflections: 0, enabled: false, include_successful: false
    end

    # A single reflection entry.
    #
    # @!attribute [r] task
    #   @return [String] The task being attempted
    # @!attribute [r] action
    #   @return [String] What action was taken
    # @!attribute [r] outcome
    #   @return [Symbol] :success, :failure, :partial
    # @!attribute [r] observation
    #   @return [String] What was observed (error message, result)
    # @!attribute [r] reflection
    #   @return [String] What to do differently next time
    # @!attribute [r] timestamp
    #   @return [Time] When this reflection was created
    Reflection = Data.define(:task, :action, :outcome, :observation, :reflection, :timestamp) do
      include TypeSupport::StatePredicates

      state_predicates :outcome, failure: :failure, success: :success

      def to_context
        "Previous attempt: #{action}\nResult: #{outcome} - #{observation}\nLesson: #{reflection}"
      end

      class << self
        def from_failure(task:, step:, reflection_text:)
          new(
            task: task.to_s.slice(0, 200),
            action: extract_action(step),
            outcome: :failure,
            observation: step.error || step.observations.to_s.slice(0, 200),
            reflection: reflection_text,
            timestamp: Time.now
          )
        end

        def from_success(task:, step:, reflection_text:)
          new(
            task: task.to_s.slice(0, 200),
            action: extract_action(step),
            outcome: :success,
            observation: step.action_output.to_s.slice(0, 200),
            reflection: reflection_text,
            timestamp: Time.now
          )
        end

        private

        def extract_action(step)
          if step.tool_calls&.any?
            step.tool_calls.map { |tc| "#{tc.name}(#{tc.arguments.keys.join(", ")})" }.join(", ")
          elsif step.code_action
            step.code_action.to_s.slice(0, 100)
          else
            "unknown action"
          end
        end
      end
    end
  end
end
