module Smolagents
  module Types
    # Task with dependencies, priority, and lifecycle tracking.
    #
    # Task extends Goal with task-specific fields for coordinated execution.
    # Tasks can depend on other tasks, have priorities, and track execution state.
    #
    # @example Creating a simple task
    #   task = Task.create(description: "Implement feature")
    #   task.actionable?  #=> true (no dependencies)
    #
    # @see TaskCoordinator For task orchestration
    # @see TaskStatus For task status queries
    Task = Data.define(
      :id, :description, :active_form, :status, :priority, :dependencies,
      :blocked_by, :parent_id, :started_at, :completed_at, :timeout_seconds,
      :result, :error, :metadata
    ) do
      # @return [Array<Symbol>] Valid task statuses
      def self.statuses = %i[pending in_progress completed failed cancelled].freeze

      # @return [Array<Symbol>] Valid priority levels
      def self.priorities = %i[low normal high critical].freeze

      # Creates a new pending task. See {TaskFactory} for full documentation.
      def self.create(description:, **)
        TaskFactory.build(description:, **)
      end

      # Status predicates
      def pending? = status == :pending
      def in_progress? = status == :in_progress
      def completed? = status == :completed
      def failed? = status == :failed
      def cancelled? = status == :cancelled
      def finished? = %i[completed failed cancelled].include?(status)
      def blocked? = blocked_by.any?
      def actionable? = pending? && !blocked?
      def critical? = priority == :critical
      def root? = parent_id.nil?

      def timed_out?
        timeout_seconds && started_at && (Time.now - started_at > timeout_seconds)
      end

      def elapsed_seconds = started_at ? (completed_at || Time.now) - started_at : nil

      # State transitions (return new Task)
      def start = with(status: :in_progress, started_at: Time.now)
      def complete(result: nil) = with(status: :completed, completed_at: Time.now, result:)
      def fail(error:) = with(status: :failed, completed_at: Time.now, error:)
      def cancel(reason: nil) = with(status: :cancelled, completed_at: Time.now, error: reason)
      def unblock(dep_id) = with(blocked_by: blocked_by - [dep_id])

      def to_s
        icons = { pending: ".", in_progress: "*", completed: "+", failed: "x", cancelled: "-" }
        blocked_info = blocked? ? " [blocked by: #{blocked_by.join(", ")}]" : ""
        "#{icons[status]} [#{priority}] #{description}#{blocked_info}"
      end
    end

    # Factory for creating Task instances with validation.
    # @api private
    module TaskFactory
      module_function

      def build(description:, active_form: nil, priority: :normal, after: [], parent_id: nil, timeout: nil,
                metadata: {})
        validate_priority!(priority)
        deps = Array(after)

        Task.new(
          id: "task_#{SecureRandom.hex(6)}", description:,
          active_form: active_form || derive_active_form(description),
          status: :pending, priority:, dependencies: deps, blocked_by: deps,
          parent_id:, started_at: nil, completed_at: nil, timeout_seconds: timeout,
          result: nil, error: nil, metadata:
        )
      end

      def validate_priority!(priority)
        return if Task.priorities.include?(priority)

        raise ArgumentError, "Invalid priority: #{priority}. Valid: #{Task.priorities.inspect}"
      end

      def derive_active_form(description)
        words = description.strip.split
        return description if words.empty?

        verb, *rest = words
        gerund = verb.end_with?("e") ? "#{verb.chomp("e")}ing" : "#{verb}ing"
        "#{gerund.capitalize} #{rest.join(" ")}".strip
      end
    end
  end
end
