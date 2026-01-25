module Smolagents
  module Types
    # Unified work unit for the work queue system.
    #
    # WorkItem represents any unit of work that can be queued and dispatched
    # to workers. It generalizes QueuedRequest to support multiple work types:
    # model generation, tool execution, code execution, and sub-agent spawning.
    #
    # @example Creating a model generation work item
    #   item = WorkItem.model_generate(
    #     messages: [ChatMessage.user("Hello")],
    #     model_id: "gpt-4",
    #     priority: :high
    #   )
    #   item.model_generate?  # => true
    #   item.high_priority?   # => true
    #
    # @example Creating a sub-agent work item
    #   item = WorkItem.sub_agent(
    #     task: "Research topic X",
    #     agent_config: { persona: :researcher, tools: [:search] }
    #   )
    #   item.sub_agent?  # => true
    #
    # @example Pattern matching on work type
    #   case item
    #   in WorkItem[type: :model_generate, payload: { messages:, model_id: }]
    #     dispatch_to_model(model_id, messages)
    #   in WorkItem[type: :sub_agent, payload: { task:, agent_config: }]
    #     spawn_agent(agent_config, task)
    #   end
    #
    # @see WorkResult For the result of processing a WorkItem
    # @see Concerns::Orchestration::WorkQueue For queue management
    WorkItem = Data.define(:id, :type, :priority, :payload, :context, :created_at, :deadline) do
      include TypeSupport::Deconstructable

      # Valid work types
      TYPES = %i[model_generate tool_call code_execution sub_agent].freeze

      # Priority levels in descending order of importance
      PRIORITIES = %i[critical high normal low].freeze

      # Calculate how long the item has been waiting.
      # @return [Float] Elapsed time in seconds since creation
      def wait_time = Time.now - created_at

      # Check if the deadline has passed.
      # @return [Boolean] True if deadline exists and has passed
      def expired? = deadline ? Time.now > deadline : false

      # Time remaining until deadline.
      # @return [Float, nil] Seconds until deadline, or nil if no deadline
      def time_remaining = deadline ? deadline - Time.now : nil

      # @!group Type Predicates

      # @return [Boolean] True if this is a model generation work item
      def model_generate? = type == :model_generate

      # @return [Boolean] True if this is a tool call work item
      def tool_call? = type == :tool_call

      # @return [Boolean] True if this is a code execution work item
      def code_execution? = type == :code_execution

      # @return [Boolean] True if this is a sub-agent spawn work item
      def sub_agent? = type == :sub_agent

      # @!endgroup

      # @!group Priority Predicates

      # @return [Boolean] True if priority is :critical
      def critical_priority? = priority == :critical

      # @return [Boolean] True if priority is :high
      def high_priority? = priority == :high

      # @return [Boolean] True if priority is :normal
      def normal_priority? = priority == :normal

      # @return [Boolean] True if priority is :low
      def low_priority? = priority == :low

      # @return [Boolean] True if priority is :critical or :high
      def elevated_priority? = critical_priority? || high_priority?

      # @!endgroup

      class << self
        # Creates a model generation work item.
        #
        # @param messages [Array<ChatMessage>] Messages to send to the model
        # @param model_id [String] Target model identifier
        # @param priority [Symbol] Priority level (:critical, :high, :normal, :low)
        # @param context [Hash] Execution context (parent_id, purpose, etc.)
        # @param deadline [Time, nil] Optional deadline for completion
        # @param kwargs [Hash] Additional model parameters (temperature, etc.)
        # @return [WorkItem]
        def model_generate(messages:, model_id:, priority: :normal, context: {}, deadline: nil, **kwargs)
          create(
            type: :model_generate,
            priority:,
            payload: { messages:, model_id:, **kwargs }.freeze,
            context:,
            deadline:
          )
        end

        # Creates a tool call work item.
        #
        # @param tool_name [String] Name of the tool to execute
        # @param args [Hash] Arguments to pass to the tool
        # @param priority [Symbol] Priority level
        # @param context [Hash] Execution context
        # @param deadline [Time, nil] Optional deadline
        # @return [WorkItem]
        def tool_call(tool_name:, args:, priority: :normal, context: {}, deadline: nil)
          create(
            type: :tool_call,
            priority:,
            payload: { tool_name:, args: }.freeze,
            context:,
            deadline:
          )
        end

        # Creates a code execution work item.
        #
        # @param code [String] Code to execute in sandbox
        # @param execution_context [Hash] Sandbox context (authorized_imports, etc.)
        # @param priority [Symbol] Priority level
        # @param context [Hash] Work item context
        # @param deadline [Time, nil] Optional deadline
        # @return [WorkItem]
        def code_execution(code:, execution_context: {}, priority: :normal, context: {}, deadline: nil)
          create(
            type: :code_execution,
            priority:,
            payload: { code:, execution_context: }.freeze,
            context:,
            deadline:
          )
        end

        # Creates a sub-agent spawn work item.
        #
        # @param task [String] Task for the sub-agent to perform
        # @param agent_config [Hash] Configuration for spawning the agent
        # @param priority [Symbol] Priority level
        # @param context [Hash] Execution context (parent_id, spawn_context, etc.)
        # @param deadline [Time, nil] Optional deadline
        # @return [WorkItem]
        def sub_agent(task:, agent_config:, priority: :normal, context: {}, deadline: nil)
          create(
            type: :sub_agent,
            priority:,
            payload: { task:, agent_config: }.freeze,
            context:,
            deadline:
          )
        end

        private

        # Internal factory with auto-generated ID and timestamp.
        def create(type:, priority:, payload:, context:, deadline:)
          new(
            id: SecureRandom.uuid,
            type:,
            priority:,
            payload:,
            context: context.freeze,
            created_at: Time.now,
            deadline:
          )
        end
      end
    end
  end
end
