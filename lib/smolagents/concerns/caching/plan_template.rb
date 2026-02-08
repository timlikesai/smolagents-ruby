module Smolagents
  module Concerns
    module Caching
      # Session-scoped plan caching for reuse across similar tasks.
      #
      # Caches generated plans by normalized task pattern, enabling reuse
      # when similar tasks are encountered. Reduces planning costs by up to
      # 76% according to research (arXiv:2505.09970).
      #
      # Uses LRU eviction when cache reaches capacity and TTL-based
      # staleness detection. Emits events for cache operations.
      #
      # @example Basic usage
      #   class MyAgent
      #     include Concerns::Caching::PlanTemplate
      #
      #     def initialize
      #       initialize_plan_cache
      #     end
      #
      #     def plan_for(task)
      #       cached = lookup_cached_plan(task)
      #       return cached.plan_content if cached
      #
      #       plan = generate_plan(task)
      #       cache_plan(task: task, plan: plan)
      #       plan
      #     end
      #   end
      #
      # @see CachedPlan For cached plan structure
      # @see PlanCacheConfig For configuration options
      module PlanTemplate
        include Events::Emitter

        def self.included(base)
          base.attr_reader :plan_cache_config
        end

        private

        # Initializes the plan cache with configuration.
        #
        # @param config [PlanCacheConfig, nil] Cache configuration
        def initialize_plan_cache(config: nil)
          @plan_cache_config = config || Types::PlanCacheConfig.default
          @plan_cache = {}
        end

        # Looks up a cached plan for a task.
        #
        # Returns nil if caching is disabled, no matching plan exists,
        # or the cached plan is stale.
        #
        # @param task [String] Task description
        # @return [CachedPlan, nil] Cached plan or nil
        def lookup_cached_plan(task)
          return nil unless plan_cache_config.enabled

          pattern = Types::CachedPlan.normalize_task(task)
          cached = @plan_cache[pattern]

          return nil unless cached
          return nil if cached.stale?(max_age_seconds: plan_cache_config.ttl_seconds)

          updated = cached.mark_used
          emit :plan_cache_hit, plan_id: updated.plan_id, reuse_count: updated.reuse_count
          @plan_cache[pattern] = updated
          updated
        end

        # Stores a plan in the cache.
        #
        # Evicts oldest entry if cache is full (LRU eviction).
        #
        # @param task [String] Task description
        # @param plan [String] Plan content
        # @param tools [Array<String>] Tool names used
        # @return [CachedPlan, nil] Cached plan or nil if disabled
        def cache_plan(task:, plan:, tools: [])
          return nil unless plan_cache_config.enabled

          cached = Types::CachedPlan.create(task:, plan:, tools:)

          evict_if_full
          @plan_cache[cached.task_pattern] = cached

          emit :plan_cached, plan_id: cached.plan_id, task_pattern: cached.task_pattern
          cached
        end

        # Checks if a cached plan exists for the task.
        #
        # @param task [String] Task description
        # @return [Boolean] True if valid cached plan exists
        def cached_plan?(task)
          pattern = Types::CachedPlan.normalize_task(task)
          cached = @plan_cache[pattern]
          return false unless cached

          !cached.stale?(max_age_seconds: plan_cache_config.ttl_seconds)
        end

        # Returns cache statistics.
        #
        # @return [Hash] Stats with :size, :max_size, :total_hits
        def plan_cache_stats
          {
            size: @plan_cache.size,
            max_size: plan_cache_config.max_size,
            total_hits: @plan_cache.values.sum(&:reuse_count)
          }
        end

        # Clears the cache.
        #
        # @return [void]
        def clear_plan_cache
          count = @plan_cache.size
          @plan_cache.clear
          emit :plan_cache_cleared, count:
        end

        # Evicts oldest entry if cache is at capacity.
        def evict_if_full
          return if @plan_cache.size < plan_cache_config.max_size

          oldest_key = @plan_cache.min_by { |_, v| v.last_used_at }&.first
          evicted = @plan_cache.delete(oldest_key) if oldest_key

          emit :plan_cache_evicted, plan_id: evicted.plan_id if evicted
        end
      end
    end
  end
end
