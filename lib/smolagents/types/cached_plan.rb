require "securerandom"

module Smolagents
  module Types
    # A cached plan with metadata for reuse across similar tasks.
    #
    # CachedPlan stores a generated plan along with its normalized task pattern,
    # enabling lookup and reuse for similar tasks. Tracks usage statistics for
    # LRU eviction and staleness detection.
    #
    # @example Creating a cached plan
    #   cached = CachedPlan.create(
    #     task: "Search for Ruby release notes",
    #     plan: "1. Search for Ruby\n2. Parse results",
    #     tools: ["search"]
    #   )
    #   cached.task_pattern  #=> "search for ruby release notes"
    #
    # @example Marking a plan as used
    #   updated = cached.mark_used
    #   updated.reuse_count  #=> 1
    #
    # @example Checking staleness
    #   cached.stale?(max_age_seconds: 3600)  #=> false
    #
    # @see PlanCacheConfig For cache configuration
    # @see Concerns::Caching::PlanTemplate For cache operations
    CachedPlan = Data.define(
      :plan_id,
      :task_pattern,
      :plan_content,
      :tool_names,
      :step_count,
      :created_at,
      :last_used_at,
      :reuse_count
    ) do
      class << self
        # Creates a new CachedPlan from a task and plan.
        #
        # @param task [String] The original task description
        # @param plan [String] The generated plan content
        # @param tools [Array<String>] Tool names used in the plan
        # @return [CachedPlan] New cached plan instance
        def create(task:, plan:, tools: [])
          now = Time.now
          new(**build_attrs(task, plan, tools, now))
        end

        # Normalizes a task for pattern matching.
        #
        # Lowercases and normalizes whitespace for consistent lookup.
        #
        # @param task [String] The task description
        # @return [String] Normalized task pattern
        def normalize_task(task) = task.to_s.downcase.gsub(/\s+/, " ").strip

        # Counts numbered steps in a plan.
        #
        # @param plan [String] The plan content
        # @return [Integer] Number of steps found
        def count_steps(plan) = plan.to_s.scan(/^\d+\./).size

        private

        def build_attrs(task, plan, tools, now)
          { plan_id: SecureRandom.uuid, task_pattern: normalize_task(task), plan_content: plan,
            tool_names: tools.freeze, step_count: count_steps(plan), created_at: now, last_used_at: now,
            reuse_count: 0 }
        end
      end

      # Marks the plan as used, updating last_used_at and incrementing reuse_count.
      #
      # @return [CachedPlan] New instance with updated usage
      def mark_used
        with(last_used_at: Time.now, reuse_count: reuse_count + 1)
      end

      # Returns the age of the cached plan in seconds.
      #
      # @return [Float] Seconds since creation
      def age_seconds = Time.now - created_at

      # Checks if the plan is stale based on maximum age.
      #
      # @param max_age_seconds [Integer] Maximum allowed age
      # @return [Boolean] True if plan exceeds max age
      def stale?(max_age_seconds: 3600) = age_seconds > max_age_seconds

      # Converts to hash for serialization.
      #
      # @return [Hash] Hash representation
      def to_h
        {
          plan_id:,
          task_pattern:,
          plan_content:,
          tool_names:,
          step_count:,
          created_at: created_at.iso8601,
          last_used_at: last_used_at.iso8601,
          reuse_count:
        }
      end
    end
  end
end
