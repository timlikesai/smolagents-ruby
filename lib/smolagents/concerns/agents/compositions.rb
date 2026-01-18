module Smolagents
  module Concerns
    # Predefined concern compositions for common agent patterns.
    #
    # Use these as shortcuts for including multiple related concerns.
    #
    # @example Full-featured agent
    #   class MyAgent
    #     include Concerns::Compositions::FullFeatured
    #   end
    #
    # @example Minimal code agent
    #   class MinimalAgent
    #     include Concerns::Compositions::MinimalCode
    #   end
    module Compositions
      # Full-featured agent with all common concerns.
      # Includes: Monitorable, ReActLoop, Control, Repetition, Evaluation,
      # StepExecution, Planning, CodeExecution
      module FullFeatured
        def self.included(base)
          base.include(Concerns::Monitorable)
          base.include(Concerns::ReActLoop)
          base.include(Concerns::ReActLoop::Control)
          base.include(Concerns::ReActLoop::Repetition)
          base.include(Concerns::Evaluation)
          base.include(Concerns::StepExecution)
          base.include(Concerns::Planning)
          base.include(Concerns::CodeExecution)
        end
      end

      # Minimal code agent.
      # Includes: ReActLoop, CodeExecution
      module MinimalCode
        def self.included(base)
          base.include(Concerns::ReActLoop)
          base.include(Concerns::CodeExecution)
        end
      end

      # Agent with self-refinement capability.
      # Includes: ReActLoop, CodeExecution, SelfRefine
      module WithRefinement
        def self.included(base)
          base.include(Concerns::ReActLoop)
          base.include(Concerns::CodeExecution)
          base.include(Concerns::SelfRefine)
        end
      end

      # Agent with cross-run memory.
      # Includes: ReActLoop, CodeExecution, ReflectionMemory
      module WithMemory
        def self.included(base)
          base.include(Concerns::ReActLoop)
          base.include(Concerns::CodeExecution)
          base.include(Concerns::ReflectionMemory)
        end
      end

      # Agent with interactive fiber control.
      # Includes: ReActLoop, Control, Planning, CodeExecution
      module Interactive
        def self.included(base)
          base.include(Concerns::ReActLoop)
          base.include(Concerns::ReActLoop::Control)
          base.include(Concerns::Planning)
          base.include(Concerns::CodeExecution)
        end
      end
    end
  end
end
