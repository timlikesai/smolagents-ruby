require_relative "event_orchestrator/lifecycle"
require_relative "event_orchestrator/routing"
require_relative "event_orchestrator/subscriptions"

module Smolagents
  module Orchestrators
    # Central event-driven orchestrator for agent coordination.
    #
    # EventOrchestrator is the hub for event routing, work dispatch, and
    # subscription management. It coordinates between the work queue,
    # worker pool, and event handlers.
    #
    # @example Basic usage
    #   orchestrator = EventOrchestrator.new
    #   orchestrator.subscribe(:step_completed) { |e| log(e) }
    #   orchestrator.start
    #
    # @example With work triggers
    #   orchestrator.trigger_work_on(AgentStepRequested) do |event|
    #     WorkItem.create(type: :agent_step, payload: { task: event.task })
    #   end
    #
    # @see WorkQueue For priority-based work dispatch
    # @see WorkerPool For thread pool management
    class EventOrchestrator
      include Events::Emitter
      include Events::Consumer
      include Concerns::Orchestration::WorkQueue
      include Concerns::Orchestration::WorkerPool

      include Lifecycle
      include Routing
      include Subscriptions

      attr_reader :id, :config, :event_queue

      # Configuration for the orchestrator.
      Config = Data.define(
        :queue_depth,
        :pool_size,
        :event_buffer_size
      ) do
        def self.default
          new(
            queue_depth: 500,
            pool_size: Concerns::Orchestration::WorkerPool::DEFAULT_POOL_SIZE,
            event_buffer_size: 1000
          )
        end
      end

      # Creates a new orchestrator.
      #
      # @param config [Config] Orchestrator configuration
      def initialize(config: Config.default)
        @id = SecureRandom.uuid
        @config = config

        initialize_state
        initialize_work_infrastructure
      end

      # Returns combined statistics from all components.
      # @return [Hash]
      def stats
        {
          id: @id,
          running: @running,
          routing: routing_stats,
          subscriptions: subscription_stats,
          work_queue: work_queue_stats,
          worker_pool: pool_stats
        }
      end

      # Submits an event for routing.
      #
      # @param event [Object] Event to route
      # @return [self]
      def submit_event(event)
        @event_queue.push(event)
        self
      end

      private

      def initialize_state
        @running = false
        @lifecycle_mutex = Mutex.new
        @routing_mutex = Mutex.new
        @subscriptions_mutex = Mutex.new

        @subscriptions = {}
        @subscription_index = {}
        @work_triggers = {}
        @event_stats = { total: 0, by_type: Hash.new(0) }
      end

      def initialize_work_infrastructure
        @event_queue = Thread::Queue.new
        init_worker_pool(size: @config.pool_size)
      end
    end
  end
end
