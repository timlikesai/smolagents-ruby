module Smolagents
  module Types
    # A wave of parallel-safe tasks.
    #
    # Wave groups tasks that can execute simultaneously because they have
    # no dependencies on each other. Used by WaveScheduler for automatic
    # parallel execution planning.
    #
    # @example Wave execution
    #   waves = WaveScheduler.compute_waves(tasks)
    #   waves.each do |wave|
    #     wave.tasks.map { |t| spawn_async(t) }.each(&:join)
    #   end
    #
    # @see WaveScheduler For wave computation
    # @see TaskCoordinator For coordinated execution
    Wave = Data.define(
      :number,      # Integer - wave number (1-indexed)
      :task_ids,    # Array<String> - task IDs in this wave
      :status,      # Symbol - :pending, :in_progress, :completed
      :started_at,  # Time, nil - when wave started
      :completed_at # Time, nil - when wave completed
    ) do
      # @return [Array<Symbol>] Valid wave statuses
      def self.statuses = %i[pending in_progress completed].freeze

      # Creates a pending wave.
      #
      # @param number [Integer] Wave number
      # @param task_ids [Array<String>] Tasks in this wave
      # @return [Wave]
      def self.create(number:, task_ids:)
        new(
          number:,
          task_ids: Array(task_ids),
          status: :pending,
          started_at: nil,
          completed_at: nil
        )
      end

      # @return [Boolean] Wave has not started
      def pending? = status == :pending

      # @return [Boolean] Wave is executing
      def in_progress? = status == :in_progress

      # @return [Boolean] Wave is done
      def completed? = status == :completed

      # @return [Integer] Number of tasks in wave
      def size = task_ids.size

      # @return [Boolean] Wave has no tasks
      def empty? = task_ids.empty?

      # @return [Float, nil] Elapsed time in seconds
      def elapsed_seconds
        return nil unless started_at

        (completed_at || Time.now) - started_at
      end

      # Start the wave.
      # @return [Wave] New wave with in_progress status
      def start
        with(status: :in_progress, started_at: Time.now)
      end

      # Complete the wave.
      # @return [Wave] New wave with completed status
      def complete
        with(status: :completed, completed_at: Time.now)
      end

      # @return [String] Summary string
      def to_s
        icon = { pending: ".", in_progress: "*", completed: "+" }[status]
        "#{icon} Wave #{number}: #{size} task(s)"
      end
    end

    # Collection of waves for execution planning.
    #
    # WavePlan represents the complete execution plan with all waves
    # and provides methods for tracking overall progress.
    WavePlan = Data.define(:waves, :total_tasks) do
      # Creates a plan from computed waves.
      #
      # @param waves [Array<Wave>] Computed waves
      # @param total_tasks [Integer] Total task count
      # @return [WavePlan]
      def self.create(waves:, total_tasks:)
        new(waves:, total_tasks:)
      end

      # @return [WavePlan] Empty plan
      def self.empty
        new(waves: [], total_tasks: 0)
      end

      # @return [Integer] Number of waves
      def wave_count = waves.size

      # @return [Boolean] Plan has no waves
      def empty? = waves.empty?

      # @return [Wave, nil] Next pending wave
      def next_wave = waves.find(&:pending?)

      # @return [Wave, nil] Currently executing wave
      def current_wave = waves.find(&:in_progress?)

      # @return [Integer] Number of completed waves
      def completed_wave_count = waves.count(&:completed?)

      # @return [Float] Progress as percentage
      def progress_percent
        return 0.0 if wave_count.zero?

        (completed_wave_count.to_f / wave_count * 100).round(1)
      end

      # @return [Boolean] All waves completed
      def all_done? = completed_wave_count == wave_count && wave_count.positive?

      # @return [String] Summary string
      def to_s
        "WavePlan: #{completed_wave_count}/#{wave_count} waves, #{total_tasks} tasks"
      end
    end
  end
end
