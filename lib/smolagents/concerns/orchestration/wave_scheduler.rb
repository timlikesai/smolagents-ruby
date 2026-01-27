module Smolagents
  module Concerns
    module Orchestration
      # Wave-based parallel execution scheduler.
      #
      # WaveScheduler analyzes task dependencies via topological sort
      # and groups parallel-safe tasks into execution waves.
      #
      # @example Computing waves from tasks
      #   waves = WaveScheduler.compute_waves(coordinator.tasks)
      #   waves.each do |wave|
      #     execute_parallel(wave.task_ids)
      #   end
      #
      # @example Using with parallel agents
      #   scheduler = WaveScheduler.new(coordinator)
      #   scheduler.execute_waves { |task| run_task(task) }
      #
      # @see Types::Wave For wave structure
      # @see Types::WavePlan For execution plan
      module WaveScheduler
        include Events::Emitter

        # Compute execution waves from tasks.
        #
        # @param tasks [Array<Types::Task>] Tasks to schedule
        # @return [Array<Types::Wave>] Ordered waves
        def self.compute_waves(tasks)
          return [] if tasks.empty?

          context = build_wave_context(tasks)
          build_waves(context)
        end

        def self.build_wave_context(tasks)
          {
            task_map: tasks.each_with_object({}) { |t, h| h[t.id] = t },
            remaining: Set.new(tasks.map(&:id)),
            wave_number: 1
          }
        end

        def self.build_waves(context)
          waves = []

          until context[:remaining].empty?
            ready = find_ready_tasks(context[:remaining], context[:task_map])
            break if ready.empty?

            waves << Types::Wave.create(number: context[:wave_number], task_ids: ready.to_a)
            context[:wave_number] += 1
            context[:remaining] -= ready
          end

          waves
        end

        # Find tasks with all dependencies satisfied.
        #
        # @param remaining [Set<String>] Unscheduled task IDs
        # @param task_map [Hash<String, Task>] Task lookup
        # @return [Set<String>] Ready task IDs
        def self.find_ready_tasks(remaining, task_map)
          remaining.select do |task_id|
            task = task_map[task_id]
            task.blocked_by.none? { |dep| remaining.include?(dep) }
          end.to_set
        end

        # Initialize scheduler with coordinator.
        #
        # @param coordinator [Types::TaskCoordinator] Task coordinator
        def initialize_wave_scheduler(coordinator)
          @wave_coordinator = coordinator
          @wave_plan = nil
        end

        # @return [Types::WavePlan, nil] Current wave plan
        attr_reader :wave_plan

        # Build execution plan from current tasks.
        #
        # @return [Types::WavePlan] Computed plan
        def build_wave_plan
          tasks = @wave_coordinator.tasks
          waves = WaveScheduler.compute_waves(tasks)

          @wave_plan = Types::WavePlan.create(waves:, total_tasks: tasks.size)
        end

        # Execute tasks in waves.
        #
        # @yield [Types::Task] Task to execute
        # @return [Types::WavePlan] Completed plan
        def execute_waves(&)
          plan = build_wave_plan
          return plan if plan.empty?

          plan.waves.each do |wave|
            execute_wave(wave, &)
          end

          @wave_plan
        end

        private

        def execute_wave(wave, &)
          emit :coord_wave_started,
               wave_number: wave.number,
               task_count: wave.size,
               total_waves: @wave_plan.wave_count

          wave_tasks = wave.task_ids.filter_map { |id| @wave_coordinator.get(id) }

          wave_tasks.each(&)

          emit :coord_wave_completed,
               wave_number: wave.number,
               task_count: wave.size
        end
      end
    end
  end
end
