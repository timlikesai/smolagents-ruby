module Smolagents
  module Concerns
    module Orchestration
      # Routes parallel execution stages to ParallelDispatch.
      #
      # Recognizes ExecutionStage objects with parallel mode and
      # dispatches them to run concurrently rather than sequentially.
      #
      # @example
      #   stage = ExecutionStage.parallel(tasks: [
      #     { agent: researcher, task: "research" },
      #     { agent: writer, task: "write" }
      #   ])
      #   execute_stage(stage)  # runs in parallel
      module ParallelExecution
        include Events::Emitter

        # Execute a stage, routing parallel stages appropriately.
        #
        # @param stage [Types::ExecutionStage] Stage to execute
        # @return [Array<Hash>] Results from execution
        def execute_stage(stage)
          if stage.respond_to?(:parallel?) && stage.parallel?
            execute_parallel_stage(stage)
          else
            execute_sequential_stage(stage)
          end
        end

        private

        def execute_parallel_stage(stage)
          tasks = stage.respond_to?(:tasks) ? stage.tasks : []
          return [] if tasks.empty?

          dispatcher = Smolagents::Tools::ManagedAgentTool::ParallelDispatch
          obj = Object.new.extend(dispatcher)
          obj.execute_parallel(tasks)
        end

        def execute_sequential_stage(stage)
          tasks = stage.respond_to?(:tasks) ? stage.tasks : []
          tasks.map do |entry|
            result = entry[:agent].run(entry[:task])
            { agent_name: entry[:agent].class.name, outcome: result.state,
              output: result.output, error: nil }
          rescue StandardError => e
            { agent_name: entry[:agent].class.name, outcome: :error,
              output: nil, error: e.message }
          end
        end
      end
    end
  end
end
