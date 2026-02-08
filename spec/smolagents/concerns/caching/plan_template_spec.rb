require "spec_helper"

RSpec.describe Smolagents::Concerns::Caching::PlanTemplate do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::Caching::PlanTemplate

      attr_reader :captured_events

      def initialize(config: nil)
        @captured_events = []
        initialize_plan_cache(config: config)
      end

      # Override emit to capture events for testing
      def emit(event_name, **kwargs)
        event = Smolagents::Events::Mappings.resolve(event_name).create(**kwargs)
        @captured_events << event
        event
      end

      # Expose private methods for testing
      public :lookup_cached_plan, :cache_plan, :cached_plan?, :plan_cache_stats, :clear_plan_cache
    end
  end

  let(:instance) { test_class.new }

  describe "#initialize_plan_cache" do
    it "uses default config when none provided" do
      expect(instance.plan_cache_config).to be_a(Smolagents::Types::PlanCacheConfig)
      expect(instance.plan_cache_config.enabled).to be true
    end

    it "accepts custom config" do
      config = Smolagents::Types::PlanCacheConfig.new(
        enabled: true,
        max_size: 50,
        ttl_seconds: 1800,
        similarity_threshold: 0.9
      )
      custom = test_class.new(config: config)

      expect(custom.plan_cache_config.max_size).to eq(50)
    end
  end

  describe "#lookup_cached_plan" do
    context "when cache is empty" do
      it "returns nil" do
        expect(instance.lookup_cached_plan("Find Ruby docs")).to be_nil
      end
    end

    context "when caching is disabled" do
      it "returns nil" do
        disabled = test_class.new(config: Smolagents::Types::PlanCacheConfig.disabled)
        disabled.cache_plan(task: "Find Ruby", plan: "1. Search")

        expect(disabled.lookup_cached_plan("Find Ruby")).to be_nil
      end
    end

    context "when matching plan exists" do
      before do
        instance.cache_plan(task: "Find Ruby docs", plan: "1. Search\n2. Parse")
      end

      it "returns cached plan" do
        cached = instance.lookup_cached_plan("Find Ruby docs")

        expect(cached).to be_a(Smolagents::Types::CachedPlan)
        expect(cached.plan_content).to eq("1. Search\n2. Parse")
      end

      it "matches normalized task patterns" do
        cached = instance.lookup_cached_plan("FIND RUBY DOCS")

        expect(cached).not_to be_nil
        expect(cached.plan_content).to eq("1. Search\n2. Parse")
      end

      it "marks plan as used" do
        instance.lookup_cached_plan("Find Ruby docs") # First lookup to increment counter
        second_lookup = instance.lookup_cached_plan("Find Ruby docs")

        expect(second_lookup.reuse_count).to eq(2)
      end

      it "emits plan_cache_hit event" do
        instance.lookup_cached_plan("Find Ruby docs")

        hit_event = instance.captured_events.find { |e| e.event_name == "plan_cache_hit" }
        expect(hit_event).not_to be_nil
        expect(hit_event.plan_id).to match(/\A[0-9a-f-]{36}\z/)
      end
    end

    context "when plan is stale" do
      it "returns nil for stale plans" do
        config = Smolagents::Types::PlanCacheConfig.new(
          enabled: true,
          max_size: 100,
          ttl_seconds: 60,
          similarity_threshold: 0.85
        )
        short_ttl = test_class.new(config: config)
        short_ttl.cache_plan(task: "Find Ruby", plan: "1. Search")

        # Simulate time passing beyond TTL
        cached = short_ttl.instance_variable_get(:@plan_cache).values.first
        old_created_at = Time.now - 120
        updated = cached.with(created_at: old_created_at)
        short_ttl.instance_variable_get(:@plan_cache)[cached.task_pattern] = updated

        expect(short_ttl.lookup_cached_plan("Find Ruby")).to be_nil
      end
    end
  end

  describe "#cache_plan" do
    it "stores plan in cache" do
      cached = instance.cache_plan(task: "Find Ruby", plan: "1. Search")

      expect(cached).to be_a(Smolagents::Types::CachedPlan)
      expect(instance.lookup_cached_plan("Find Ruby")).not_to be_nil
    end

    it "emits plan_cached event" do
      instance.cache_plan(task: "Find Ruby", plan: "1. Search")

      cached_event = instance.captured_events.find { |e| e.event_name == "plan_cached" }
      expect(cached_event).not_to be_nil
      expect(cached_event.task_pattern).to eq("find ruby")
    end

    it "stores tools in cached plan" do
      cached = instance.cache_plan(
        task: "Find Ruby",
        plan: "1. Search",
        tools: ["search", "web"]
      )

      expect(cached.tool_names).to eq(["search", "web"])
    end

    it "returns nil when caching is disabled" do
      disabled = test_class.new(config: Smolagents::Types::PlanCacheConfig.disabled)

      result = disabled.cache_plan(task: "Find Ruby", plan: "1. Search")

      expect(result).to be_nil
    end
  end

  describe "#cached_plan?" do
    it "returns false when no matching plan" do
      expect(instance.cached_plan?("Find Ruby")).to be false
    end

    it "returns true when matching plan exists" do
      instance.cache_plan(task: "Find Ruby", plan: "1. Search")

      expect(instance.cached_plan?("Find Ruby")).to be true
    end

    it "returns true for normalized task patterns" do
      instance.cache_plan(task: "Find Ruby", plan: "1. Search")

      expect(instance.cached_plan?("FIND RUBY")).to be true
    end

    it "returns false for stale plans" do
      config = Smolagents::Types::PlanCacheConfig.new(
        enabled: true,
        max_size: 100,
        ttl_seconds: 60,
        similarity_threshold: 0.85
      )
      short_ttl = test_class.new(config: config)
      short_ttl.cache_plan(task: "Find Ruby", plan: "1. Search")

      # Make plan stale
      cached = short_ttl.instance_variable_get(:@plan_cache).values.first
      old_created_at = Time.now - 120
      updated = cached.with(created_at: old_created_at)
      short_ttl.instance_variable_get(:@plan_cache)[cached.task_pattern] = updated

      expect(short_ttl.cached_plan?("Find Ruby")).to be false
    end
  end

  describe "eviction" do
    it "evicts oldest entry when cache is full" do
      config = Smolagents::Types::PlanCacheConfig.new(
        enabled: true,
        max_size: 2,
        ttl_seconds: 3600,
        similarity_threshold: 0.85
      )
      small_cache = test_class.new(config: config)

      # Cache two plans
      small_cache.cache_plan(task: "Task 1", plan: "1. First")
      # Make first plan older
      cache = small_cache.instance_variable_get(:@plan_cache)
      first_cached = cache["task 1"]
      cache["task 1"] = first_cached.with(last_used_at: Time.now - 100)

      small_cache.cache_plan(task: "Task 2", plan: "2. Second")

      # Add third - should evict first (oldest)
      small_cache.cache_plan(task: "Task 3", plan: "3. Third")

      expect(small_cache.cached_plan?("Task 1")).to be false
      expect(small_cache.cached_plan?("Task 2")).to be true
      expect(small_cache.cached_plan?("Task 3")).to be true
    end

    it "emits plan_cache_evicted event" do
      config = Smolagents::Types::PlanCacheConfig.new(
        enabled: true,
        max_size: 1,
        ttl_seconds: 3600,
        similarity_threshold: 0.85
      )
      small_cache = test_class.new(config: config)

      small_cache.cache_plan(task: "Task 1", plan: "1. First")
      small_cache.cache_plan(task: "Task 2", plan: "2. Second")

      evicted_event = small_cache.captured_events.find { |e| e.event_name == "plan_cache_evicted" }
      expect(evicted_event).not_to be_nil
    end

    it "uses LRU eviction based on last_used_at" do
      config = Smolagents::Types::PlanCacheConfig.new(
        enabled: true,
        max_size: 2,
        ttl_seconds: 3600,
        similarity_threshold: 0.85
      )
      small_cache = test_class.new(config: config)

      small_cache.cache_plan(task: "Task 1", plan: "1. First")
      small_cache.cache_plan(task: "Task 2", plan: "2. Second")

      # Use Task 1, making Task 2 the oldest
      small_cache.lookup_cached_plan("Task 1")

      # Add third - should evict Task 2 (least recently used)
      small_cache.cache_plan(task: "Task 3", plan: "3. Third")

      expect(small_cache.cached_plan?("Task 1")).to be true
      expect(small_cache.cached_plan?("Task 2")).to be false
      expect(small_cache.cached_plan?("Task 3")).to be true
    end
  end

  describe "#plan_cache_stats" do
    it "returns correct size" do
      instance.cache_plan(task: "Task 1", plan: "1. First")
      instance.cache_plan(task: "Task 2", plan: "2. Second")

      stats = instance.plan_cache_stats

      expect(stats[:size]).to eq(2)
      expect(stats[:max_size]).to eq(100)
    end

    it "returns total hits" do
      instance.cache_plan(task: "Task 1", plan: "1. First")
      instance.lookup_cached_plan("Task 1")
      instance.lookup_cached_plan("Task 1")

      stats = instance.plan_cache_stats

      expect(stats[:total_hits]).to eq(2)
    end

    it "returns zero for empty cache" do
      stats = instance.plan_cache_stats

      expect(stats[:size]).to eq(0)
      expect(stats[:total_hits]).to eq(0)
    end
  end

  describe "#clear_plan_cache" do
    it "removes all cached plans" do
      instance.cache_plan(task: "Task 1", plan: "1. First")
      instance.cache_plan(task: "Task 2", plan: "2. Second")

      instance.clear_plan_cache

      expect(instance.plan_cache_stats[:size]).to eq(0)
    end

    it "emits plan_cache_cleared event with count" do
      instance.cache_plan(task: "Task 1", plan: "1. First")
      instance.cache_plan(task: "Task 2", plan: "2. Second")

      instance.clear_plan_cache

      cleared_event = instance.captured_events.find { |e| e.event_name == "plan_cache_cleared" }
      expect(cleared_event).not_to be_nil
      expect(cleared_event.count).to eq(2)
    end
  end

  describe "event emission" do
    it "emits events in correct order during cache operations" do
      instance.cache_plan(task: "Find Ruby", plan: "1. Search")
      instance.lookup_cached_plan("Find Ruby")

      event_types = instance.captured_events.map(&:event_name)
      expect(event_types).to include("plan_cached")
      expect(event_types).to include("plan_cache_hit")
    end
  end
end
