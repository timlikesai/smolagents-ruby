module Smolagents
  module Builders
    # Build and agent construction methods for AgentBuilder.
    #
    # Handles the final build step and agent argument assembly.
    module AgentBuildConcern
      # Build the configured agent.
      #
      # Creates an Agent instance with all configured options. The model block
      # is evaluated at this point (lazy instantiation).
      #
      # @return [Agents::Agent] The configured agent
      # @raise [ArgumentError] If model is not configured
      #
      # @example Building an agent
      #   agent = Smolagents.agent
      #     .model { Smolagents::OpenAIModel.new(model_id: "gpt-4") }
      #     .tools(:search)
      #     .max_steps(10)
      #     .build
      #   agent.class.name
      #   #=> "Smolagents::Agents::Agent"
      def build
        agent = Agents::Agent.new(**build_agent_args)
        configure_event_driven(agent)
        configure_call_log(agent)
        configure_checkpoints(agent)
        configure_semantic_breaker(agent)
        configure_debug(agent)
        configuration[:handlers].each { |event_type, block| agent.on(event_type, &block) }
        emit_agent_configured(agent)
        agent
      end

      # Return a copy of the current configuration.
      #
      # @return [Hash] Configuration hash
      def config = configuration.dup

      # Return a string representation of the builder.
      #
      # @return [String] Builder description
      def inspect
        tools_desc = (configuration[:tool_names] + configuration[:tool_instances].map do |t|
          t.name || t.class.name
        end).join(", ")
        "#<AgentBuilder tools=[#{tools_desc}] handlers=#{configuration[:handlers].size}>"
      end

      private

      # Build agent initialization arguments from configuration.
      # @return [Hash] Arguments for Agent.new
      def build_agent_args
        cfg = configuration
        {
          model: resolve_model,
          tools: resolve_tools,
          config: build_agent_config(cfg),
          managed_agents: cfg[:managed_agents].empty? ? nil : cfg[:managed_agents],
          logger: cfg[:logger],
          executor: cfg[:executor]
        }.compact
      end

      # Build an AgentConfig from builder configuration.
      # @param cfg [Hash] Full configuration
      # @return [Types::AgentConfig]
      def build_agent_config(cfg)
        Types::AgentConfig.create(
          max_steps: cfg[:max_steps],
          authorized_imports: cfg[:authorized_imports],
          spawn_config: cfg[:spawn_config],
          memory_config: cfg[:memory_config],
          planning: build_planning_config(cfg),
          behavioral: build_behavioral_config(cfg),
          observability: build_observability_config(cfg)
        )
      end

      def build_planning_config(cfg)
        return nil if cfg[:planning_interval].nil? && cfg[:planning_templates].nil?

        Types::PlanningConfig.create(
          interval: cfg[:planning_interval],
          templates: cfg[:planning_templates]
        )
      end

      def build_behavioral_config(cfg)
        Types::BehavioralConfig.create(
          evaluation_enabled: cfg.fetch(:evaluation_enabled, true),
          custom_instructions: cfg[:custom_instructions],
          refine_config: cfg[:refine_config],
          sync_events: cfg[:sync_events] || false,
          reasoning_mode: cfg.fetch(:reasoning_mode, :chain_of_thought)
        )
      end

      def build_observability_config(cfg)
        return nil if cfg[:observe_mode].nil? && cfg[:summarizer_model].nil?

        Types::ObservabilityConfig.create(
          observe_mode: cfg[:observe_mode] || :with_summary,
          summarizer_model: cfg[:summarizer_model]
        )
      end

      # Configure event-driven mode if enabled.
      # @param agent [Agents::Agent] The agent to configure
      def configure_event_driven(agent)
        return unless configuration[:event_driven]

        agent.extend(Concerns::Orchestration::EventDriven)
        agent.step_timeout = configuration[:step_timeout]
        agent.connect_orchestrator(configuration[:orchestrator]) if configuration[:orchestrator]
      end

      # Configure call logging for testing.
      def configure_call_log(agent)
        return unless configuration[:call_log_enabled] || Testing::TestMode.test_mode?

        agent.extend(Testing::CallLogSupport)
        agent.enable_call_log
      end

      # Configure debug observability (stats, verbose logging, failure capture).
      def configure_debug(agent)
        return unless configuration[:debug_mode]

        agent.extend(Concerns::StatsTracking).send(:initialize_stats)
        agent.extend(Concerns::VerboseSubscriber)
        Events::Registry.by_tier(:user).each { |et| agent.on(et) { |e| agent.send(:log_verbose_event, e) } }
        agent.extend(Concerns::Resilience::FailureCapture).send(:initialize_failure_capture)
      end

      # Emit the agent_configured event after construction.
      # @param agent [Agents::Agent] The built agent
      def emit_agent_configured(agent)
        agent.emit :agent_configured,
                   agent_name: configuration[:persona_name] || "unnamed",
                   tools: collect_tool_names,
                   model_purposes: collect_model_purposes
      end

      # Collect tool names from both symbol names and instances.
      # @return [Array<String>] Tool names
      def collect_tool_names
        names = configuration[:tool_names].map(&:to_s)
        instances = configuration[:tool_instances].map { |t| t.respond_to?(:name) ? t.name : t.class.name }
        names + instances
      end

      # Collect model purposes from configuration.
      # @return [Array<Symbol>] Model purposes
      def collect_model_purposes
        pool_config = configuration[:model_pool_config]
        return [:execution] if pool_config.nil? || !pool_config.multi_model?

        pool_config.purposes
      end
    end
  end
end
