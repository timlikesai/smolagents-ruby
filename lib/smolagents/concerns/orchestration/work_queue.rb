require_relative "work_queue/operations"
require_relative "work_queue/dispatch"
require_relative "work_queue/worker"
require_relative "work_queue/events"

module Smolagents
  module Concerns
    module Orchestration
      # Priority-based work queue for event-driven agent orchestration.
      #
      # WorkQueue generalizes RequestQueue to support any type of work item
      # (model generation, tool calls, code execution, sub-agents) with
      # four-level priority buckets.
      #
      # @example Basic usage
      #   orchestrator = Orchestrator.new
      #   orchestrator.extend(WorkQueue)
      #   orchestrator.enable_work_queue
      #
      #   item = WorkItem.model_generate(messages: msgs, model_id: "gpt-4", priority: :high)
      #   orchestrator.enqueue_work(item) do |result|
      #     handle_result(result)
      #   end
      #
      # @example Priority handling
      #   # Critical items are processed before high, high before normal, etc.
      #   orchestrator.enqueue_work(WorkItem.sub_agent(task: "urgent", ..., priority: :critical))
      #   orchestrator.enqueue_work(WorkItem.tool_call(tool_name: "search", ..., priority: :low))
      #
      # @see WorkItem For work item types
      # @see WorkResult For result handling
      # @see RequestQueue For the model-specific queue this generalizes
      module WorkQueue
        def self.extended(base)
          extend_modules(base)
          initialize_state(base)
        end

        def self.included(base)
          include_modules(base)
        end

        def self.extend_modules(base)
          base.extend(Events::Emitter) unless base.singleton_class.include?(Events::Emitter)
          [Operations, Worker, QueueEvents].each { |mod| base.extend(mod) }
        end

        def self.include_modules(base)
          base.include(Events::Emitter) unless base.include?(Events::Emitter)
          [Operations, Worker, QueueEvents].each { |mod| base.include(mod) }
        end

        def self.initialize_state(base)
          initial_state.each { |name, value| base.instance_variable_set(:"@#{name}", value) }
        end

        def self.initial_state
          {
            work_queue_enabled: false,
            work_queue_max_depth: nil,
            priority_queues: nil,
            work_callbacks: nil,
            worker_thread: nil,
            work_processing: false,
            work_stats: { total: 0, by_type: Hash.new(0), wait_times: [], mutex: Mutex.new }
          }
        end

        # Priority levels in processing order (highest to lowest).
        PRIORITIES = %i[critical high normal low].freeze

        # Enable the work queue.
        # @param max_depth [Integer, nil] Maximum total queue depth (default: 500)
        # @return [self]
        def enable_work_queue(max_depth: 500)
          return self if @work_queue_enabled

          @work_queue_enabled = true
          @work_queue_max_depth = max_depth
          @priority_queues = PRIORITIES.to_h { |p| [p, Thread::Queue.new] }
          @work_callbacks = {}
          start_work_worker
          self
        end

        # Disable the work queue and stop the worker.
        # @return [self]
        def disable_work_queue
          return self unless @work_queue_enabled

          @work_queue_enabled = false
          stop_work_worker
          @priority_queues = nil
          @work_callbacks = nil
          self
        end

        # Check if work queue is enabled.
        # @return [Boolean]
        def work_queue_enabled? = @work_queue_enabled

        # Total number of work items waiting across all priorities.
        # @return [Integer]
        def work_queue_depth
          return 0 unless @priority_queues

          @priority_queues.values.sum(&:size)
        end

        # Number of items waiting at a specific priority.
        # @param priority [Symbol] Priority level
        # @return [Integer]
        def queue_depth_at(priority)
          @priority_queues&.dig(priority)&.size || 0
        end

        # Check if currently processing work.
        # @return [Boolean]
        def work_processing? = @work_processing

        # Get work queue statistics.
        # @return [Hash] Queue statistics snapshot
        def work_queue_stats
          return empty_work_stats unless @work_stats

          @work_stats[:mutex].synchronize { build_work_stats }
        end

        # Returns empty stats when work queue not yet initialized.
        def empty_work_stats
          { total_depth: 0, by_priority: {}, processing: false,
            total_processed: 0, by_type: {}, avg_wait_ms: 0, max_wait_ms: 0 }
        end

        private

        def build_work_stats
          wait_times = @work_stats[:wait_times].last(100)
          {
            total_depth: work_queue_depth,
            by_priority: PRIORITIES.to_h { |p| [p, queue_depth_at(p)] },
            processing: @work_processing,
            total_processed: @work_stats[:total],
            by_type: @work_stats[:by_type].dup,
            avg_wait_ms: average_wait_ms(wait_times),
            max_wait_ms: wait_times.max || 0
          }
        end

        def average_wait_ms(times) = times.empty? ? 0 : times.sum / times.size
      end
    end
  end
end
