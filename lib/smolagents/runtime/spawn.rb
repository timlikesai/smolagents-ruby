module Smolagents
  module Runtime
    # Dynamic agent spawning at runtime.
    #
    # Provides the spawn() function that agents use in their code
    # to create child agents dynamically.
    module Spawn
      # Creates a spawn function bound to the parent agent's context.
      #
      # @param spawn_config [SpawnConfig] Configuration limits
      # @param parent_memory [AgentMemory] Parent's memory for context extraction
      # @param parent_model [Model] Parent's model (default for children)
      # @param parent_fiber [Fiber, nil] For control request bubbling
      # @return [Proc] The spawn function
      def self.create_spawn_function(spawn_config:, parent_memory:, parent_model:, parent_fiber: nil)
        SpawnFunction.new(spawn_config:, parent_memory:, parent_model:, parent_fiber:).to_proc
      end

      def self.resolve_tools(tool_names, spawn_config)
        names = tool_names.empty? ? spawn_config.allowed_tools : tool_names
        names.filter_map { |name| Tools.get(name.to_s) }
      end

      # Internal class that holds state and implements spawn logic.
      class SpawnFunction
        def initialize(spawn_config:, parent_memory:, parent_model:, parent_fiber:)
          @spawn_config = spawn_config
          @parent_memory = parent_memory
          @parent_model = parent_model
          @parent_fiber = parent_fiber
          @children_count = 0
        end

        def to_proc = method(:call).to_proc

        def call(model: nil, tools: [], task: nil)
          validate_spawn_allowed!
          validate_model!(model)
          validate_tools!(tools)

          child = build_child_agent(model, tools)
          execute_or_wrap(child, task)
        end

        private

        attr_reader :spawn_config, :parent_memory, :parent_model, :parent_fiber

        def validate_spawn_allowed!
          raise SpawnError.new("Spawning not configured", reason: "Spawning not configured") unless spawn_config

          @children_count += 1
          return unless @children_count > spawn_config.max_children

          raise_spawn_error("Max children (#{spawn_config.max_children}) exceeded")
        end

        def validate_model!(model)
          return unless model && !spawn_config.model_allowed?(model)

          raise_spawn_error("Model :#{model} not allowed. Allowed: #{spawn_config.allowed_models.join(", ")}")
        end

        def validate_tools!(tools)
          tools.each do |tool|
            next if spawn_config.tool_allowed?(tool)

            raise_spawn_error("Tool :#{tool} not allowed. Allowed: #{spawn_config.allowed_tools.join(", ")}")
          end
        end

        def build_child_agent(model, tools)
          resolved_model = model ? Smolagents.get_model(model) : parent_model
          resolved_tools = Spawn.resolve_tools(tools, spawn_config)

          Agents::Agent.new(model: resolved_model, tools: resolved_tools, max_steps: 10)
        end

        def execute_or_wrap(child, task)
          if task
            # Context extracted but not used for immediate execution
            spawn_config.inherit_scope.extract_from(parent_memory, task:)
            child.run(task).output
          else
            context = spawn_config.inherit_scope.extract_from(parent_memory, task: "")
            SpawnedAgent.new(agent: child, context:, parent_fiber:)
          end
        end

        def raise_spawn_error(msg) = raise SpawnError.new(msg, reason: msg)
      end

      # Wrapper for a spawned agent that hasn't been run yet.
      SpawnedAgent = Data.define(:agent, :context, :parent_fiber) do
        def run(task)
          agent.run(task).output
        end
      end
    end
  end
end
