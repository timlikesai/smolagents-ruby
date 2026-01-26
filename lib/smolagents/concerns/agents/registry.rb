module Smolagents
  module Concerns
    module Agents
      # Registry of agent concerns with metadata for composition.
      #
      # @example Check concern dependencies
      #   Agents::Registry::CONCERNS[:planning][:requires]  # => [:react_loop]
      #
      # @example Get all standalone concerns
      #   Agents::Registry.standalone  # => [:react_loop, :self_refine, ...]
      module Registry
        # Concern metadata. Keys: :path, :requires, :auto_includes, :notes
        CONCERNS = {
          react_loop: { path: "react_loop", requires: [], auto_includes: %i[core execution],
                        notes: "Base loop, includes Events" },
          react_loop_core: { path: "react_loop/core", requires: [], notes: "Setup and run entry points" },
          react_loop_execution: { path: "react_loop/execution", requires: [],
                                  auto_includes: %i[completion error_handling],
                                  notes: "Main loop, step monitoring" },
          react_loop_control: { path: "react_loop/control", requires: [:react_loop],
                                notes: "Fiber bidirectional control" },
          react_loop_repetition: { path: "react_loop/repetition", requires: [:react_loop],
                                   notes: "Loop detection, stuck agents" },
          evaluation: { path: nil, requires: [:react_loop], notes: "Metacognition phase" },
          completion_validation: { path: "completion_validation", requires: [:react_loop],
                                   notes: "Validates completion before final_answer" },
          planning: { path: "planning", requires: [:react_loop], auto_includes: [:templates],
                      notes: "Pre-Act planning" },
          code_execution: { path: nil, requires: [],
                            auto_includes: %i[code_generation code_parsing execution_context],
                            notes: "Can use standalone" },
          step_execution: { path: nil, requires: [], notes: "Step timing wrapper" },
          monitorable: { path: nil, requires: [], auto_includes: [:events_emitter],
                         notes: "Can use standalone" },
          managed_agents: { path: "managed", requires: [], notes: "Sub-agent delegation" },
          async_tools: { path: "async", requires: [], notes: "Parallel tool execution" },
          early_yield: { path: "early_yield", requires: [], notes: "Speculative execution" },
          specialized: { path: "specialized", requires: [], notes: "DSL for agent definition" },
          self_refine: { path: "self_refine", requires: [], auto_includes: %i[loop feedback prompts],
                         notes: "Iterative improvement" },
          reflection_memory: { path: "reflection_memory", requires: [],
                               auto_includes: %i[store injection analysis],
                               notes: "Cross-run learning" },
          mixed_refinement: { path: "mixed_refinement", requires: [], notes: "Cross-model refinement" }
        }.freeze

        class << self
          def standalone = CONCERNS.select { _2[:requires].empty? }.keys
          def dependent = CONCERNS.reject { _2[:requires].empty? }.keys
          def [](name) = CONCERNS[name]

          def load(name)
            meta = CONCERNS[name] or raise ArgumentError, "Unknown concern: #{name}"
            require_relative meta[:path] if meta[:path]
          end

          def load_all = CONCERNS.each_value { require_relative it[:path] if it[:path] }
        end
      end
    end
  end
end
