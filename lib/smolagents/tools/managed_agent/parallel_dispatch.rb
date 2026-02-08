module Smolagents
  module Tools
    class ManagedAgentTool < Tool
      # Parallel execution support for managed agents.
      #
      # Launches multiple sub-agents concurrently using threads,
      # collects their results, and provides error isolation so
      # one failing agent doesn't crash others.
      module ParallelDispatch
        include Events::Emitter

        # Execute multiple agent tasks in parallel.
        #
        # @param tasks_by_agent [Array<Hash>] Each has :agent and :task keys
        # @return [Array<Hash>] Results with :agent_name, :outcome, :output, :error
        def execute_parallel(tasks_by_agent)
          threads = tasks_by_agent.map { |e| Thread.new(e) { |entry| run_single(entry) } }
          collect_results(threads, tasks_by_agent)
        end

        private

        def run_single(entry)
          agent = entry[:agent]
          name = agent_name_for(agent)
          launch = emit_launch(name, entry[:task])
          result = agent.run(entry[:task])
          emit_complete(launch, name, result)
          { agent_name: name, outcome: result.state, output: result.output, error: nil }
        rescue StandardError => e
          { agent_name: agent_name_for(entry[:agent]), outcome: :error, output: nil, error: e.message }
        end

        def emit_launch(name, task) = emit(Events::SubAgentLaunched.create(agent_name: name, task:))

        def emit_complete(launch, name, result)
          emit(Events::SubAgentCompleted.create(
                 launch_id: launch&.id, agent_name: name, outcome: result.state,
                 output: result.output&.to_s, token_usage: result.token_usage,
                 step_count: result.step_count, duration: result.duration
               ))
        end

        def collect_results(threads, tasks_by_agent)
          threads.zip(tasks_by_agent).map do |thread, entry|
            thread.value
          rescue StandardError => e
            { agent_name: agent_name_for(entry[:agent]), outcome: :error, output: nil, error: e.message }
          end
        end

        def agent_name_for(agent)
          agent.respond_to?(:name) ? agent.name : agent.class.name.split("::").last
        end
      end
    end
  end
end
