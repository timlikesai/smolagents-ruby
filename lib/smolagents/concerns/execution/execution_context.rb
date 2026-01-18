module Smolagents
  module Concerns
    # Manages execution context and variable scope.
    #
    # Handles executor setup, tools initialization, and building
    # the variable environment for code execution.
    #
    # @example Setting up execution
    #   setup_code_execution(executor: my_executor)
    #   finalize_code_execution
    #
    # @example Building variables
    #   vars = build_execution_variables(action_step)
    #   # => { "query" => "test", "_step" => 3, "_max_steps" => 10, ... }
    #
    # @see CodeExecution For the full execution pipeline
    # @see LocalRubyExecutor For the default executor
    module ExecutionContext
      # Initialize code execution infrastructure.
      #
      # @param executor [Executor, nil] Code executor (defaults to LocalRubyExecutor)
      # @param authorized_imports [Array<String>, nil] Allowed require paths
      # @return [void]
      def setup_code_execution(executor: nil, authorized_imports: nil)
        @authorized_imports = authorized_imports || Smolagents.configuration.authorized_imports
        @executor = executor || LocalRubyExecutor.new
      end

      # Finalize code execution setup.
      #
      # Sends the tools to the executor so code can access them.
      #
      # @return [void]
      def finalize_code_execution
        @executor.send_tools(tools)
      end

      # Builds variables hash for code execution.
      #
      # Includes state variables, step context, and spawn function if configured.
      #
      # @param action_step [ActionStep, nil] Current step for context
      # @return [Hash] Variables to inject into execution sandbox
      def build_execution_variables(action_step = nil)
        vars = @state.dup
        vars["spawn"] = create_spawn_function if @spawn_config

        if action_step && @max_steps
          step_num = action_step.step_number || 0
          vars["_step"] = step_num
          vars["_max_steps"] = @max_steps
          vars["_steps_remaining"] = [@max_steps - step_num, 0].max
        end

        vars
      end

      # Creates a spawn function for child agent creation.
      #
      # @return [Proc] Lambda that creates and runs child agents
      def create_spawn_function
        Runtime::Spawn.create_spawn_function(
          spawn_config: @spawn_config,
          parent_memory: @memory,
          parent_model: @model
        )
      end
    end
  end
end
