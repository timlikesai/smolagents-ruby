require_relative "event_driven/async_step"
require_relative "event_driven/callbacks"
require_relative "event_driven/async_loop"

module Smolagents
  module Concerns
    module Orchestration
      # Event-driven execution concern for async agent orchestration.
      #
      # Transforms the synchronous ReActLoop into an asynchronous,
      # callback-based execution model. Integrates with the EventOrchestrator
      # for centralized event routing and work dispatch.
      #
      # @example Basic async execution
      #   agent.extend(EventDriven)
      #   agent.connect_orchestrator(orchestrator)
      #
      #   agent.run_async("Find Ruby info",
      #     on_step: ->(step) { puts "Step #{step.step_number}" },
      #     on_complete: ->(result) { puts "Done: #{result.output}" }
      #   )
      #
      # @example With explicit callbacks
      #   agent.on_step_complete { |step| log(step) }
      #   agent.on_task_complete { |result| notify(result) }
      #   agent.on_error { |e, ctx| alert(e) }
      #   agent.run_async("Complex task")
      #
      # @see EventDriven::AsyncStep For async step execution
      # @see EventDriven::Callbacks For callback management
      # @see EventDriven::AsyncLoop For the async execution loop
      # @see Orchestrators::EventOrchestrator For the central coordinator
      module EventDriven
        def self.included(base)
          base.include(Events::Emitter)
          base.include(AsyncStep)
          base.include(Callbacks)
          base.include(AsyncLoop)
          base.attr_accessor :orchestrator, :step_timeout
        end

        # Support for extend (runtime inclusion)
        def self.extended(base)
          base.extend(Events::Emitter)
          base.extend(AsyncStep)
          base.extend(Callbacks)
          base.extend(AsyncLoop)
        end

        # Instance variable accessors (work with both include and extend)
        def orchestrator = @orchestrator

        def orchestrator=(value)
          @orchestrator = value
        end

        def step_timeout = @step_timeout

        def step_timeout=(value)
          @step_timeout = value
        end

        # Connects to an event orchestrator.
        #
        # @param orchestrator [Orchestrators::EventOrchestrator]
        # @return [self]
        def connect_orchestrator(orchestrator)
          @orchestrator = orchestrator
          connect_to(orchestrator.event_queue) if orchestrator.respond_to?(:event_queue)
          self
        end

        # Disconnects from the orchestrator.
        # @return [self]
        def disconnect_orchestrator
          @orchestrator = nil
          @event_queue = nil
          self
        end

        # Returns execution statistics.
        # @return [Hash]
        def async_stats
          {
            pending_runs: @async_runs&.size || 0,
            pending_callbacks: @step_callbacks&.size || 0,
            orchestrator_connected: !@orchestrator.nil?
          }
        end

        # Executes a step directly (synchronous fallback).
        #
        # Used when no orchestrator is connected or for testing.
        #
        # @param work_item [Types::WorkItem] Step work item
        # @return [Types::WorkResult] Step result
        def execute_agent_step(work_item)
          start_time = Time.now
          step_result = run_step_from_work_item(work_item)
          build_step_result(work_item, step_result, start_time)
        rescue StandardError => e
          build_step_error(work_item, e, start_time)
        end

        private

        def run_step_from_work_item(work_item)
          step(work_item.payload[:task], step_number: work_item.payload[:step_number])
        end

        def build_step_result(work_item, step_result, start_time)
          Types::WorkResult.success(
            work_item_id: work_item.id, value: step_result,
            duration_ms: duration_since(start_time)
          )
        end

        def build_step_error(work_item, error, start_time)
          Types::WorkResult.error(
            work_item_id: work_item.id, error:,
            duration_ms: duration_since(start_time)
          )
        end

        def duration_since(start_time)
          ((Time.now - start_time) * 1000).to_i
        end
      end
    end
  end
end
