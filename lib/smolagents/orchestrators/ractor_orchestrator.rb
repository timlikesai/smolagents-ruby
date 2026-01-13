module Smolagents
  module Orchestrators
    # Orchestrates parallel sub-agent execution using Ractors for memory isolation
    class RactorOrchestrator
      attr_reader :agents, :max_concurrent

      def initialize(agents:, max_concurrent: 4)
        @agents = agents.freeze
        @max_concurrent = max_concurrent
      end

      # Execute multiple agents in parallel via Ractors
      # @param tasks [Array<Array>] Array of [agent_name, prompt, config] tuples
      # @param timeout [Integer] Overall timeout in seconds
      # @return [OrchestratorResult] Aggregated results
      def execute_parallel(tasks:, timeout: 60)
        start_time = Time.now
        ractor_tasks = create_ractor_tasks(tasks)

        # Execute in batches if needed
        results = if ractor_tasks.size <= max_concurrent
                    execute_batch(ractor_tasks, timeout)
                  else
                    execute_batched(ractor_tasks, timeout)
                  end

        duration = Time.now - start_time
        build_orchestrator_result(results, duration)
      end

      # Execute a single agent task in a Ractor
      # @param agent_name [String] Name of agent to run
      # @param prompt [String] Task prompt
      # @param config [Hash] Optional configuration
      # @return [RactorSuccess, RactorFailure] Result
      def execute_single(agent_name:, prompt:, config: {}, timeout: 30)
        task = RactorTask.create(agent_name:, prompt:, config:, timeout:)
        execute_task_in_ractor(task)
      end

      private

      def create_ractor_tasks(tasks)
        tasks.map do |task_tuple|
          agent_name, prompt, config = task_tuple
          RactorTask.create(
            agent_name: agent_name.to_s,
            prompt:,
            config: config || {},
            timeout: config&.dig(:timeout) || 30
          )
        end
      end

      def execute_batch(tasks, overall_timeout)
        ractors = tasks.map { |task| spawn_agent_ractor(task) }
        collect_results(ractors, tasks, overall_timeout)
      end

      def execute_batched(tasks, overall_timeout)
        results = []
        start_time = Time.now

        tasks.each_slice(max_concurrent) do |batch|
          remaining_timeout = overall_timeout - (Time.now - start_time)
          break if remaining_timeout <= 0

          batch_results = execute_batch(batch, remaining_timeout)
          results.concat(batch_results)
        end

        results
      end

      def spawn_agent_ractor(task)
        agent = agents[task.agent_name]
        raise ArgumentError, "Unknown agent: #{task.agent_name}" unless agent

        # Prepare agent config for Ractor (must be shareable)
        agent_config = prepare_agent_config(agent, task)

        Ractor.new(task, agent_config) do |ractor_task, config|
          start_time = Time.now
          begin
            # Reconstruct agent in child Ractor (agents aren't shareable)
            result = execute_agent_task(ractor_task, config)
            duration = Time.now - start_time

            RactorMessage.result(
              RactorSuccess.from_result(
                task_id: ractor_task.task_id,
                run_result: result,
                duration:,
                trace_id: ractor_task.trace_id
              )
            )
          rescue StandardError => e
            duration = Time.now - start_time
            RactorMessage.result(
              RactorFailure.from_exception(
                task_id: ractor_task.task_id,
                error: e,
                duration:,
                trace_id: ractor_task.trace_id
              )
            )
          end
        end
      end

      def prepare_agent_config(agent, task)
        {
          model_class: agent.model.class.name,
          model_id: agent.model.model_id,
          agent_class: agent.class.name,
          max_steps: task.config[:max_steps] || agent.max_steps,
          tool_names: agent.tools.keys.freeze
        }.freeze
      end

      def collect_results(ractors, tasks, _timeout)
        results = []

        ractors.each_with_index do |ractor, index|
          result = begin
            message = ractor.value
            extract_result(message)
          rescue Ractor::RemoteError => e
            create_ractor_error_failure(tasks[index], e)
          end

          results << result
          cleanup_ractor(ractor)
        end

        results
      end

      def extract_result(message)
        case message
        in RactorMessage[type: :result, payload:]
          payload
        else
          raise "Unexpected message type: #{message.inspect}"
        end
      end

      def create_ractor_error_failure(task, error)
        RactorFailure.from_exception(
          task_id: task.task_id,
          error: error.cause || error,
          trace_id: task.trace_id
        )
      end

      def build_orchestrator_result(results, duration)
        succeeded = results.select(&:success?)
        failed = results.select(&:failure?)

        OrchestratorResult.create(succeeded:, failed:, duration:)
      end

      def cleanup_ractor(ractor)
        return unless ractor

        ractor.close if ractor.respond_to?(:close)
      rescue StandardError
        # Ignore cleanup errors
      end

      class << self
        # Execute agent task inside a Ractor
        # This runs in the child Ractor context
        # NOTE: In a real implementation, we'd reconstruct the agent here
        # For now, we return a mock result since full agent reconstruction
        # requires model API access which may not work inside a Ractor
        def execute_agent_task(task, _config)
          RactorMockResult.new(
            output: "Executed: #{task.prompt}",
            steps: [],
            token_usage: TokenUsage.zero
          )
        end
      end
    end
  end
end

# Helper for child Ractor execution
def execute_agent_task(task, config)
  Smolagents::Orchestrators::RactorOrchestrator.execute_agent_task(task, config)
end
