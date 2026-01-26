module Smolagents
  module Orchestrators
    # Pool for parallel agent execution using threads.
    #
    # AgentPool runs multiple agents concurrently, each in its own thread.
    # Code execution within each agent is sandboxed via Ractors (handled
    # by the agent's executor).
    #
    # @example Running agents in parallel
    #   pool = AgentPool.new(agents: { "researcher" => researcher, "analyst" => analyst })
    #   result = pool.execute_parallel(tasks: [
    #     ["researcher", "Find info about Ruby 4.0"],
    #     ["analyst", "Analyze the findings"]
    #   ])
    #
    # @example Running a single agent
    #   result = pool.execute_single(agent_name: "researcher", prompt: "Find info")
    #
    class AgentPool
      attr_reader :agents, :max_concurrent

      # @param agents [Hash<String, Agent>] Named agents available in the pool
      # @param max_concurrent [Integer] Maximum concurrent agent executions
      def initialize(agents:, max_concurrent: 4)
        @agents = agents.freeze
        @max_concurrent = max_concurrent
      end

      # Execute multiple agents in parallel.
      #
      # @param tasks [Array<Array>] Array of [agent_name, prompt, config] tuples
      # @param timeout [Integer] Overall timeout in seconds
      # @return [PoolResult] Aggregated results
      def execute_parallel(tasks:, timeout: 60)
        start_time = Time.now
        task_data = build_tasks(tasks)

        results = if task_data.size <= max_concurrent
                    execute_batch(task_data, timeout)
                  else
                    execute_batched(task_data, timeout)
                  end

        duration = Time.now - start_time
        PoolResult.new(results:, duration:)
      end

      # Execute a single agent task.
      #
      # @param agent_name [String] Name of agent to run
      # @param prompt [String] Task prompt
      # @param config [Hash] Optional configuration overrides
      # @param timeout [Integer] Timeout in seconds
      # @return [TaskResult] Execution result
      def execute_single(agent_name:, prompt:, config: {}, timeout: 30)
        agent = agents[agent_name]
        raise ArgumentError, "Unknown agent: #{agent_name}" unless agent

        execute_agent(agent, prompt, config, timeout)
      end

      private

      TaskData = Data.define(:agent_name, :prompt, :config, :timeout)

      def build_tasks(tasks)
        tasks.map do |agent_name, prompt, config|
          TaskData.new(
            agent_name: agent_name.to_s,
            prompt:,
            config: config || {},
            timeout: config&.dig(:timeout) || 30
          )
        end
      end

      def execute_batch(task_data, overall_timeout)
        threads = task_data.map { |task| Thread.new { execute_task(task) } }
        collect_results(threads, Time.now + overall_timeout)
      end

      def collect_results(threads, deadline)
        threads.map { |thread| join_thread(thread, deadline) }
      end

      def join_thread(thread, deadline)
        remaining = [deadline - Time.now, 0].max
        thread.join(remaining)
        thread.value
      rescue StandardError => e
        TaskResult.failure(error: e)
      end

      def execute_batched(task_data, overall_timeout)
        results = []
        start_time = Time.now

        task_data.each_slice(max_concurrent) do |batch|
          remaining_timeout = overall_timeout - (Time.now - start_time)
          break if remaining_timeout <= 0

          batch_results = execute_batch(batch, remaining_timeout)
          results.concat(batch_results)
        end

        results
      end

      def execute_task(task)
        agent = agents[task.agent_name]
        raise ArgumentError, "Unknown agent: #{task.agent_name}" unless agent

        execute_agent(agent, task.prompt, task.config, task.timeout)
      end

      def execute_agent(agent, prompt, config, timeout)
        effective_agent = apply_config(agent, config)
        run_with_timeout(effective_agent, prompt, timeout)
      end

      def run_with_timeout(agent, prompt, timeout)
        start_time = Time.now
        thread = Thread.new { agent.run(prompt) }
        return timeout_result(timeout) unless thread.join(timeout)

        TaskResult.success(run_result: thread.value, duration: Time.now - start_time)
      rescue StandardError => e
        TaskResult.failure(error: e)
      end

      def timeout_result(timeout)
        TaskResult.failure(error: Smolagents::TimeoutError.new(operation: "Agent execution", duration: timeout))
      end

      def apply_config(agent, config)
        return agent if config.empty?

        # For now, config overrides aren't applied - agents run as configured
        # Future: could support per-task max_steps, etc.
        agent
      end
    end

    # Result of a single task execution.
    TaskResult = Data.define(:status, :run_result, :error, :duration) do
      def success? = status == :success
      def failure? = status == :failure

      def output = run_result&.output
      def steps = run_result&.steps

      class << self
        def success(run_result:, duration:)
          new(status: :success, run_result:, error: nil, duration:)
        end

        def failure(error:, duration: 0)
          new(status: :failure, run_result: nil, error:, duration:)
        end
      end
    end

    # Aggregated result from parallel execution.
    PoolResult = Data.define(:results, :duration) do
      def success_count = results.count(&:success?)
      def failure_count = results.count(&:failure?)
      def total_count = results.size

      def all_succeeded? = failure_count.zero?
      def any_failed? = failure_count.positive?

      def successes = results.select(&:success?)
      def failures = results.select(&:failure?)
    end
  end
end
