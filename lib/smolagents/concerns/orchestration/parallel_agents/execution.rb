module Smolagents
  module Concerns
    module Orchestration
      module ParallelAgents
        # Agent building and future creation for parallel execution.
        module Execution
          private

          # Creates an AgentFuture from a spec and starts execution.
          #
          # @param spec [Hash] Agent specification
          # @param timeout [Numeric, nil] Timeout for this agent
          # @return [Executors::AgentFuture]
          def create_and_start_future(spec, timeout: nil)
            agent = resolve_agent(spec)
            task = spec[:task] || raise(ArgumentError, "Task required in spec")

            future = Executors::AgentFuture.new(
              agent:,
              task:,
              context: build_spawn_context(spec),
              timeout:
            )
            future.execute!
          end

          # Resolves an agent from spec - uses provided agent or builds one.
          #
          # @param spec [Hash] Agent specification
          # @return [Agent]
          def resolve_agent(spec)
            return spec[:agent] if spec[:agent]

            build_agent_from_spec(spec)
          end

          # Builds an agent from a specification hash.
          #
          # @param spec [Hash] Specification with :persona, :tools, etc.
          # @return [Agent]
          # rubocop:disable Metrics/AbcSize -- builder chain
          def build_agent_from_spec(spec)
            builder = Smolagents.agent.model { spawn_model }

            builder = builder.as(spec[:persona]) if spec[:persona]
            builder = builder.tools(*spec[:tools]) if spec[:tools]&.any?
            builder = builder.max_steps(spec[:max_steps] || 5)
            builder = builder.instructions(spec[:instructions]) if spec[:instructions]

            builder.build
          end
          # rubocop:enable Metrics/AbcSize

          # Gets the model to use for spawned agents.
          # Override in including class if needed.
          #
          # @return [Model]
          def spawn_model
            respond_to?(:model) ? model : raise(NotImplementedError, "spawn_model not defined")
          end

          # Builds context for the spawned agent.
          #
          # @param spec [Hash] Agent specification
          # @return [Hash] Frozen context hash
          def build_spawn_context(spec)
            {
              parent_id: respond_to?(:agent_id) ? agent_id : nil,
              persona: spec[:persona],
              spawned_at: Time.now
            }.compact.freeze
          end
        end
      end
    end
  end
end
