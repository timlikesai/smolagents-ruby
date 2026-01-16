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

        module ClassMethods
          # Defines lazy step filter methods for each step type.
          #
          # Generates methods like `action_steps`, `planning_steps`, `task_steps`
          # that return lazy enumerators filtered by step type.
          def define_step_filters
            step_types = {
              action: Types::ActionStep,
              planning: Types::PlanningStep,
              task: Types::TaskStep
            }

            step_types.each do |name, type|
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
