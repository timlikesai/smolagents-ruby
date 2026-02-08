module Smolagents
  module Runtime
    module Memory
      # Step filtering with lazy enumeration for AgentMemory.
      #
      # Uses Ruby metaprogramming to generate type-specific step accessors
      # that return lazy enumerators for efficient processing.
      module StepFiltering
        def self.included(base)
          base.extend(ClassMethods)
          base.define_step_filters
        end

        # Step type → class mapping for filter method generation.
        STEP_TYPES = {
          action: Types::ActionStep, planning: Types::PlanningStep,
          task: Types::TaskStep, summary: Types::SummaryStep
        }.freeze

        module ClassMethods
          # Defines lazy step filter methods for each step type.
          #
          # Generates methods like `action_steps`, `planning_steps`, `task_steps`
          # that return lazy enumerators filtered by step type.
          def define_step_filters
            StepFiltering::STEP_TYPES.each do |name, type|
              define_method(:"#{name}_steps") do
                steps.lazy.select { |step| step.is_a?(type) }
              end
            end
          end
        end
      end
    end
  end
end
