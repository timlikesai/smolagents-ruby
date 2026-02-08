# Caching concern registrations.
module Smolagents
  module Concerns
    Registry.tap do |r|
      # === Caching ===
      r.register :plan_template_cache,
                 Smolagents::Concerns::Caching::PlanTemplate,
                 category: :caching,
                 dependencies: %i[events_emitter],
                 provides: %i[lookup_cached_plan cache_plan cached_plan? plan_cache_stats clear_plan_cache],
                 description: "Session-scoped plan caching for reuse across similar tasks"
    end
  end
end
