module Smolagents
  module Types
    module Ractor
      # Task submitted to a child Ractor for agent execution.
      #
      # RactorTask encapsulates all information needed to run an agent task
      # in an isolated Ractor, including configuration and tracing.
      #
      # @example Creating a task
      #   task = Types::RactorTask.create(
      #     agent_name: "researcher",
      #     prompt: "Find latest news on Ruby 4.0",
      #     timeout: 60
      #   )
      RactorTask = Data.define(:task_id, :agent_name, :prompt, :config, :timeout, :trace_id) do
        # Creates a new RactorTask with auto-generated IDs and deep-frozen config.
        #
        # @param agent_name [String] the name of the agent to execute
        # @param prompt [String] the task prompt/instructions
        # @param config [Hash] agent configuration (default: {})
        # @param timeout [Integer] execution timeout in seconds (default: 30)
        # @param trace_id [String, nil] optional trace ID for request tracking
        # @return [RactorTask] a new task instance
        def self.create(agent_name:, prompt:, config: {}, timeout: 30, trace_id: nil)
          new(
            task_id: SecureRandom.uuid,
            agent_name:,
            prompt:,
            config: deep_freeze(config),
            timeout:,
            trace_id: trace_id || SecureRandom.uuid
          )
        end

        # Deep freezes objects to ensure Ractor shareability.
        #
        # @param obj [Object] the object to freeze
        # @return [Object] the frozen object
        def self.deep_freeze(obj)
          case obj
          when Hash then deep_freeze_hash(obj)
          when Array then obj.map { |v| deep_freeze(v) }.freeze
          when String then freeze_string(obj)
          else obj
          end
        end

        def self.deep_freeze_hash(hash)
          hash.transform_keys { |k| deep_freeze(k) }.transform_values { |v| deep_freeze(v) }.freeze
        end

        def self.freeze_string(str) = str.frozen? ? str : str.dup.freeze

        # Deconstructs the task for pattern matching.
        #
        # @param _ [Object] ignored
        # @return [Hash{Symbol => Object}] hash of all task attributes
        def deconstruct_keys(_) = { task_id:, agent_name:, prompt:, config:, timeout:, trace_id: }
      end
    end

    # Re-export at Types level for backwards compatibility
    RactorTask = Ractor::RactorTask
  end
end
