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

      # Class methods for Ractor callbacks (must be public for cross-Ractor access)
      def self.build_success_result(task_data, result)
        { type: :success, task_id: task_data[:task_id], trace_id: task_data[:trace_id],
          output: result.output, steps_taken: result.steps&.size || 0, token_usage: result.token_usage }
      end

      def self.build_failure_result(task_data, error)
        { type: :failure, task_id: task_data[:task_id], trace_id: task_data[:trace_id],
          error_class: error.class.name, error_message: error.message }
      end

      private

      def execute_task_in_ractor(task)
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        ractor = spawn_agent_ractor(task)
        raw_result = ractor.value
        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
        result = wrap_ractor_result(raw_result, task, duration)
        cleanup_ractor(ractor)
        result
      rescue Ractor::RemoteError => e
        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
        create_ractor_error_failure(task, e, duration)
      end

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
        # Track start time for each Ractor at spawn time
        ractor_data = tasks.map do |task|
          start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          ractor = spawn_agent_ractor(task)
          { ractor:, task:, start_time: }
        end
        collect_results(ractor_data, overall_timeout)
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

        task_hash = build_task_hash(task)
        agent_config = prepare_agent_config(agent, task)

        Ractor.new(task_hash, agent_config) do |task_data, config|
          result = Smolagents::Orchestrators::RactorOrchestrator.execute_agent_task(task_data, config)
          Smolagents::Orchestrators::RactorOrchestrator.build_success_result(task_data, result)
        rescue StandardError => e
          Smolagents::Orchestrators::RactorOrchestrator.build_failure_result(task_data, e)
        end
      end

      def build_task_hash(task)
        { task_id: task.task_id, agent_name: task.agent_name, prompt: task.prompt, trace_id: task.trace_id }.freeze
      end

      def prepare_agent_config(agent, task)
        {
          model_class: agent.model.class.name,
          model_id: agent.model.model_id,
          model_config: extract_model_config(agent.model),
          agent_class: agent.class.name,
          max_steps: task.config[:max_steps] || agent.max_steps,
          tool_names: agent.tools.keys.freeze,
          planning_interval: agent.planning_interval,
          custom_instructions: agent.instance_variable_get(:@custom_instructions)
        }.freeze
      end

      def extract_model_config(model)
        config = {}
        config[:api_base] = model.instance_variable_get(:@client)&.uri_base if model.respond_to?(:generate)
        if model.instance_variable_defined?(:@temperature)
          config[:temperature] =
            model.instance_variable_get(:@temperature)
        end
        if model.instance_variable_defined?(:@max_tokens)
          config[:max_tokens] =
            model.instance_variable_get(:@max_tokens)
        end
        config.compact.freeze
      end

      def collect_results(ractor_data, _timeout)
        ractor_data.map do |data|
          ractor = data[:ractor]
          task = data[:task]
          start_time = data[:start_time]

          result = begin
            raw_result = ractor.value
            duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
            wrap_ractor_result(raw_result, task, duration)
          rescue Ractor::RemoteError => e
            duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
            create_ractor_error_failure(task, e, duration)
          end

          cleanup_ractor(ractor)
          result
        end
      end

      def wrap_ractor_result(raw_result, _task, duration)
        case raw_result[:type]
        when :success then build_ractor_success(raw_result, duration)
        when :failure then build_ractor_failure(raw_result, duration)
        else raise "Unexpected result type: #{raw_result.inspect}"
        end
      end

      def build_ractor_success(result, duration)
        RactorSuccess.new(task_id: result[:task_id], output: result[:output], steps_taken: result[:steps_taken],
                          token_usage: result[:token_usage], duration:, trace_id: result[:trace_id])
      end

      def build_ractor_failure(result, duration)
        RactorFailure.new(
          task_id: result[:task_id], error_class: result[:error_class], error_message: result[:error_message],
          steps_taken: 0, duration:, trace_id: result[:trace_id]
        )
      end

      def create_ractor_error_failure(task, error, duration = 0)
        RactorFailure.from_exception(
          task_id: task.task_id,
          error: error.cause || error,
          trace_id: task.trace_id,
          duration:
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
        # Execute agent task inside a Ractor.
        # This runs in the child Ractor context, reconstructing the agent
        # from serializable config since agents aren't Ractor-shareable.
        #
        # @param task_data [Hash] Task data with :task_id, :agent_name, :prompt, :trace_id
        # @param config [Hash] Agent reconstruction config from prepare_agent_config
        # @return [RunResult] The agent's run result
        # @raise [AgentError] When reconstruction or execution fails
        def execute_agent_task(task_data, config)
          api_key = ENV.fetch("SMOLAGENTS_API_KEY") do
            raise Smolagents::AgentConfigurationError, "SMOLAGENTS_API_KEY required for Ractor execution"
          end

          model = reconstruct_model(config, api_key)
          tools = reconstruct_tools(config[:tool_names])
          agent = reconstruct_agent(config, model, tools)

          agent.run(task_data.prompt)
        end

        private

        # Reconstructs a model inside a Ractor using the Ractor-safe model class.
        # The ruby-openai gem uses global configuration which isn't Ractor-safe,
        # so we use our own RactorModel with Net::HTTP instead.
        def reconstruct_model(config, api_key)
          model_opts = { model_id: config[:model_id], api_key: }
          model_opts.merge!(config[:model_config]) if config[:model_config]
          Smolagents::Models::RactorModel.new(**model_opts)
        end

        def reconstruct_tools(tool_names)
          tool_names.map do |name|
            tool = Smolagents::Tools.get(name)
            unless tool
              raise Smolagents::AgentConfigurationError,
                    "Unknown tool: #{name}. Available: #{Smolagents::Tools.names.join(", ")}"
            end

            tool
          end
        end

        def reconstruct_agent(config, model, tools)
          agent_class = Object.const_get(config[:agent_class])
          agent_opts = {
            model:,
            tools:,
            max_steps: config[:max_steps]
          }
          agent_opts[:planning_interval] = config[:planning_interval] if config[:planning_interval]
          agent_opts[:custom_instructions] = config[:custom_instructions] if config[:custom_instructions]

          agent_class.new(**agent_opts)
        rescue NameError => e
          raise Smolagents::AgentConfigurationError, "Unknown agent class: #{config[:agent_class]} - #{e.message}"
        end
      end
    end
  end
end
