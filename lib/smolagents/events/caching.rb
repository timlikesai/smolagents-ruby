# Caching-related events for plan template caching.
module Smolagents
  module Events
    extend DSL

    # Plan cache hit event
    define_event :PlanCacheHit,
                 fields: %i[plan_id reuse_count],
                 category: :caching, description: "Fired when a cached plan is found and reused"

    # Plan cached event
    define_event :PlanCached,
                 fields: %i[plan_id task_pattern],
                 category: :caching, description: "Fired when a new plan is stored in cache"

    # Plan cache evicted event
    define_event :PlanCacheEvicted,
                 fields: %i[plan_id],
                 category: :caching, description: "Fired when a plan is evicted from cache due to capacity"

    # Plan cache cleared event
    define_event :PlanCacheCleared,
                 fields: %i[count],
                 category: :caching, description: "Fired when the plan cache is cleared"
  end
end
