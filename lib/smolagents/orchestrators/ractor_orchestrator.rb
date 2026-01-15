require_relative "agent_serializer"
require_relative "agent_reconstructor"
require_relative "result_collector"

module Smolagents
  module Orchestrators
    # Orchestrates parallel sub-agent execution using Ractors for memory isolation.
    #
    # Delegates to:
    # - AgentSerializer for preparing agent config for Ractor transfer
    # - AgentReconstructor for rebuilding agents inside Ractors
    # - ResultCollector for collecting and wrapping Ractor results
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

        results = if ractor_tasks.size <= max_concurrent
                    execute_batch(ractor_tasks, timeout)
                  else
                    execute_batched(ractor_tasks, timeout)
                  end

        duration = Time.now - start_time
        ResultCollector.build_orchestrator_result(results, duration)
      end

      # Execute a single agent task in a Ractor
      # @param agent_name [String] Name of agent to run
      # @param prompt [String] Task prompt
      # @param config [Hash] Optional configuration
      # @return [RactorSuccess, RactorFailure] Result
      def execute_single(agent_name:, prompt:, config: {}, timeout: 30)
        task = Types::RactorTask.create(agent_name:, prompt:, config:, timeout:)
        execute_task_in_ractor(task)
      end

      # Class methods for Ractor callbacks (must be public for cross-Ractor access)
      def self.build_success_result(task_data, result)
        { type: :success, task_id: task_data[:task_id], trace_id: task_data[:trace_id],
          output: result.output, steps_taken: result.steps&.size || 0, token_usage: result.token_usage }
      end

      def self.build_failure_result(task_data, error)
        { type: :failure, task_id: task_data[:task_id], trace_id: task_data[:trace_id],
          error_class: error.class.name, error_message: error.message }
      end

      def self.execute_agent_task(task_data, config)
        AgentReconstructor.execute_agent_task(task_data, config)
      end

      private

      def execute_task_in_ractor(task)
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        ractor = spawn_agent_ractor(task)
        raw_result = ractor.value
        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
        result = ResultCollector.wrap_ractor_result(raw_result, task, duration)
        ResultCollector.cleanup_ractor(ractor)
        result
      rescue Ractor::RemoteError => e
        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
        ResultCollector.create_ractor_error_failure(task, e, duration)
      end

      def create_ractor_tasks(tasks)
        tasks.map do |task_tuple|
          agent_name, prompt, config = task_tuple
          Types::RactorTask.create(
            agent_name: agent_name.to_s,
            prompt:,
            config: config || {},
            timeout: config&.dig(:timeout) || 30
          )
        end
      end

      def execute_batch(tasks, overall_timeout)
        ractor_data = tasks.map do |task|
          start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          ractor = spawn_agent_ractor(task)
          { ractor:, task:, start_time: }
        end
        ResultCollector.collect_results(ractor_data, overall_timeout)
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

        task_hash = AgentSerializer.build_task_hash(task)
        agent_config = AgentSerializer.prepare_agent_config(agent, task)

        Ractor.new(task_hash, agent_config) do |task_data, config|
          result = Smolagents::Orchestrators::RactorOrchestrator.execute_agent_task(task_data, config)
          Smolagents::Orchestrators::RactorOrchestrator.build_success_result(task_data, result)
        rescue StandardError => e
          Smolagents::Orchestrators::RactorOrchestrator.build_failure_result(task_data, e)
        end
      end
    end
  end
end
